#!/bin/bash

# -e: para a execução se algum comando falhar
# -o: garante que erros em pipes não sejam ocultados
set -euo pipefail


# ----------------------------------
# DEFINIÇÃO DE VARIÁVEIS E ATRIBUTOS
# ----------------------------------
declare -i NC_PORT=10044
declare -r LOG_FILE="log.csv"
AC_MODE=0
CPP_FILE=""
BLUE='\033[34m'
RED='\033[1;31m'
GREEN='\033[32m'
WHITE='\033[1;37m'
YELLOW='\033[33m'
CYAN='\033[0;36m'
BOLD_GREEN='\033[1;32m'
GRAY='\033[0;90m'
RESET='\033[0m'

# -------------------------
# FUNÇÃO DE INSERÇÃO DO LOG
# -------------------------
register_log() {
	local status="$1"
	local detail="${2:-}"
	local cur_date=$(date "+%d-%m-%Y %H:%M:%S")
	local base_name=$(basename "$CPP_FILE")

	if [ -n "$detail" ]; then
		echo "$cur_date,$base_name,$status,$detail" >> "$LOG_FILE"
	else 		
		echo "$cur_date,$base_name,$status" >> "$LOG_FILE"
	fi
}


# ---------------------------------------------------------
# FUNÇÃO PARA REMOVER TODOS OS ARQUIVOS TEMPORARIOS GERADOS
# ---------------------------------------------------------
remove() {
	rm -f exec_file my_out*.txt out*.txt in*.txt 2>/dev/null
}


# -------------------------------
# VALIDAÇÃO E PARSE DE PARÂMETROS
# -------------------------------
if [ "$#" -eq 0 ]; then
	echo -e "Uso: $0 [--ac] <caminho/para/arquivo.cpp>" >&2
	exit 1
fi

while [ "$#" -gt 0 ]; do
	case "$1" in
		--ac)
			AC_MODE=1
			shift
			;;
		*.[cC][pP][pP])
			CPP_FILE="$1"
			shift
			;;
		*)
			echo -e "Erro: Parâmetro não conhecido '$1'." >&2
			exit 1
			;;
	esac
done

# se a string estiver vazia
if [ -z "$CPP_FILE" ]; then
	echo -e "Nenhum arquivo .cpp foi informado" >&2
	exit 1
fi

# cria o arquivo de log, se ele não existir
if [ ! -f "$LOG_FILE" ]; then
	touch "$LOG_FILE"
fi


# ----------------------------------
# CAPTURA DO JSON E CRIAÇÃO DE CACHE
# ----------------------------------
CACHE_FILE=".cache_$(basename "$CPP_FILE").json"

# verifica se já existe o arquivo de cache (se não, faz a captura do JSON) 
if [ ! -f "$CACHE_FILE" ]; then
	# executa em segundo plano a abertura de porta, manda a mensagem de OK para o protocolo HTTP e insere no arquivo raw
	( echo -e "HTTP/1.1 200 OK\r\n\r\n" | nc -l -p "$NC_PORT" > raw_json.tmp ) &

	# pega o PID do processo em segundo plano (o nc)
	NC_PID="$!"

	# pra visualização de um loading
	loading='-\|/'
	i=0

	# se repete enquanto o nc não receber o json do competitive companion
	while kill -0 "$NC_PID" 2>/dev/null; do
		i=$(( (i+1) % 4 ))
		printf "\rAguardando envio do Competitive Companion na porta %s... %s"	"$NC_PORT" "${loading:$i:1}"
		sleep 0.1
	done
	printf "\rAguardando envio do Competitive Companion na porta %s... Concluído!\n" "$NC_PORT"

	# guarda no arquivo de cache somente a partir do { (onde começa o json) 
	sed -n '/^{/ p' raw_json.tmp > "$CACHE_FILE"

	rm -f raw_json.tmp
else
	echo -e "${BLUE}Cache encontrado para $(basename "$CPP_FILE"). Pulando captura da porta...${RESET}"
fi

JSON_FILE=$(cat "$CACHE_FILE")

if [ -z "$JSON_FILE" ]; then
	echo -e "${RED}Error: Nenhum dado válido capturado${RESET}" >&2
	rm -f "$CACHE_FILE"
	exit 1
fi


# ---------------
# PARSING DO NOME
# ---------------
PROBLEM_NAME=$(echo -n "$JSON_FILE" | sed -n 's/.*name":"\([^"]*\).*/\1/p')


# --------------------
# IMPLEMENTAÇÃO NO GIT
# --------------------
if [ "$AC_MODE" -eq 1 ]; then
	echo -e "${GRAY}Modo AC ativado. Efetuando o commit no GitHub...${RESET}"
	git add "$CPP_FILE"
	git commit "$CPP_FILE" -m "$(basename "$CPP_FILE") - $PROBLEM_NAME"

	register_log "AC (Accepted)" "Submissao direta"
	echo -e "${BOLD_GREEN}Código inserido no repositório e registrado no log.${RESET}"
	exit 0
fi


# ---------------------------
# PARSING DOS DADOS RESTANTES
# ---------------------------
TIME_LIMIT=$(echo -n ""$JSON_FILE" | sed 's/,/\n/g' | grep '"timeLimit":' | sed 's/"timeLimit":\([0-9]*\)/\1/')

echo -e "${WHITE}Problema: $PROBLEM_NAME | Tempo Limite: ${TIME_LIMIT}ms${RESET}"

remove

# os comandos de dentro do awk não são interpretados pela bash
echo "$JSON_FILE" | awk '
# usa o RS para separar os testes e o FS para separar a entrada e a saída de cada teste
BEGIN { RS="\"input\":\""; FS="\",\"output\":\"" }
NR > 1 {
	in_str = $1
	split ($2, arr, "\"")
	out_str = arr[1]

	# substitui os caracteres \n por quebras de linhas de verdade
	gsub(/\\n/, "\n", in_str)
	gsub(/\\n/, "\n", out_str)

	# define os nomes e redireciona as saídas para os ficheiros
	# usa o printf para garantir que a saída terá a quebra de linha e não o caractere \n
	file_in = "in" (NR-1) ".txt"
	file_out = "out" (NR-1) ".txt"
	printf "%s", in_str > file_in
	printf "%s", out_str > file_out
}'
# conta quantos casos testes foram gerados
TESTS_COUNT=$(ls -1 in*.txt | wc -l)
echo -e "${CYAN}Foram gerados $TESTS_COUNT casos de teste locais a partir da plataforma${RESET}"


# ---------------------------
# COMPILAÇÃO E LAÇOS DE TESTE
# ---------------------------
echo -e "${YELLOW}Iniciando a compilação do arquivo: $CPP_FILE...${RESET}"

# manda o erro de compilação (se houver) para o arquivo temporário ce_error.tmp
g++ -Wall -O2 "$CPP_FILE" -o exec_file 2> ce_error.tmp || { 
	echo -e "${RED}CE (Compilation Error)${RESET}" >&2
	ERRO_COMPILACAO=$(head -n 1 ce_error.tmp | tr ',' ';')
	register_log "CE" "Erro: $ERRO_COMPILACAO"
	remove
	exit 1
}

echo -e "${YELLOW}Rodando testes locais...${RESET}"

# converte o tempo de ms para seg (coloca um tempo minimo de 1 seg  senao nao funciona kkkk
TIME_SEC=$(( TIME_LIMIT/1000 ))
if [ "$TIME_SEC" -eq 0 ]; then
	TIME_SEC=1
fi

FULL_PASS=1

# itera sobre todos os ficheiros de entrada
for in_file in in*.txt; do
	# remove o prefixo in e o sufixo .txt pra pegar só o numero
	test_num="${in_file#in}"
	test_num="${test_num%.txt}"

	out_file="out${test_num}.txt"
	my_out="my_out${test_num}.txt"

	# executa o binário controlando o tempo e armazena a saída
	timeout "${TIME_SEC}s" ./exec_file < "$in_file" > "$my_out"

	# pega o código de sáida do binário ou do timeout
	exit_code="$?"

	echo -n "Teste $test_num: "

	if [ "$exit_code" -eq 124 ]; then
		echo -e "${RED}TLE (Time Limit Exceeded)${RESET}"
		register_log "TLE" "Falha no Teste $test_num"
		FULL_PASS=0
	elif [ "$exit_code" -ne 0 ]; then
		echo -e "${RED}RTE (Runtime Error)${RESET}"
		register_log "RTE" "Falha no Teste $test_num"
		FULL_PASS=0
	else
		# usa a flag -w pra ignorar diferencas de espacos em branco
		if diff -w "$out_file" "$my_out" > /dev/null 2>&1; then
			echo -e "${GREEN}Passou (AC local)${RESET}"
		else
			echo -e "${RED}WA (Wrong Answer)${RESET}"
			register_log "WA" "Falha no Teste $test_num"
			FULL_PASS=0
		fi
	fi
done

if [ "$FULL_PASS" -eq 1 ]; then
	echo -e "${BOLD_GREEN}Todos os testes locais passaram com sucesso!${RESET}"
	register_log "AC Local" "Passou em todos os testes" 
fi

remove