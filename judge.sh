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
REFRESH=0
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


# -------------------------------
# VALIDAÇÃO E PARSE DE PARÂMETROS
# -------------------------------
if [ "$#" -eq 0 ]; then
	echo -e "Uso: $0 [--ac] [--refresh] <caminho/para/arquivo.cpp>" >&2
	exit 1
fi

while [ "$#" -gt 0 ]; do
	case "$1" in
		--ac)
			AC_MODE=1
			shift
			;;
		--refresh)
			REFRESH=1
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


# -------------------------------
# CRIAÇÃO DO DIRETÓRIO TEMPORÁRIO
# -------------------------------
# cria um diretório exclusivo para os arquivos temporários
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/judge.XXXXXX")

# define os caminhos dos arquivos temporários
EXEC_FILE="$TMP_DIR/exec_file"
RAW_JSON="$TMP_DIR/raw_json.tmp"
HTTP_RESPONSE="$TMP_DIR/http_response.tmp"
COMP_ERROR="$TMP_DIR/comp_error.tmp"

# variável para identificar o processo do nc 
NC_PID=""

# função para limpar arquivos sos temporários
cleanup(){
	# encerra o nc se o programa for interrompido durante a captura
	if [ -n "$NC_PID" ]; then
		kill "$NC_PID" 2>/dev/null || true
		# aguarda a conclusão do processo em segundo plano
		wait "$NC_PID" 2>/dev/null || true
	fi

	# remove o diretório temporario
	rm -rf -- "$TMP_DIR" 2>/dev/null || true
}

# executa a limpeza ao finalizar o script e em interrupções
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM


# ----------------------------------
# CAPTURA DO JSON E CRIAÇÃO DE CACHE
# ----------------------------------
CACHE_FILE=".cache_$(basename "$CPP_FILE").json"

# verifica se solicitou uma nova captura do json
if [ "$REFRESH" -eq 1 ]; then
	rm -f -- "$CACHE_FILE"
fi

# verifica se já existe o arquivo de cache (se não, faz a captura do JSON) 
if [ ! -s "$CACHE_FILE" ]; then
	# cria a resposta http que o nc vai mandar pra extensão
	printf 'HTTP/1.1 200 OK\r\n\r\n' > "$HTTP_RESPONSE"

	# executa em segundo plano a abertura de porta, envia a resposta e insere a requisicao arquivo raw
	nc -l -p "$NC_PORT" < "$HTTP_RESPONSE" > "$RAW_JSON" & 

	# pega o PID do processo em segundo plano (o nc)
	NC_PID="$!"

	# pra visualização de um loading
	loading='-\|/'
	i=0

	# aguarda enquanto o netcat tiver em execução 
	while kill -0 "$NC_PID" 2>/dev/null; do
		i=$(( (i+1) % 4 ))
		printf "\rAguardando envio do Competitive Companion na porta %s... %s"	"$NC_PORT" "${loading:$i:1}"
		sleep 0.1
	done
	printf "\rAguardando envio do Competitive Companion na porta %s... Concluído!\n" "$NC_PORT"

	# recupera o código de saída do processo netcat 
	if wait "$NC_PID"; then
		NC_PID=""
	else
		NC_STATUS=$?
		NC_PID=""

		echo -e "${RED}Erro ao receber os dados do Competitive Companion. Código: $NC_STATUS${RESET}" >&2
		exit 1
	fi

	# guarda, no arquivo de cache, todo o conteúdo do json posterior à primeira linha que comece com {
	sed -n '/^{/,$ p' "$RAW_JSON" > "$CACHE_FILE"

	# verifica se capturou alguma coisa memso 
	if [ ! -s "$CACHE_FILE" ]; then
		echo -e "${RED}Erro: Nenhum JSON válido foi capturado.${RESET}" >&2
		rm -f -- "$CACHE_FILE"
        exit 1
	fi
else
	echo -e "${BLUE}Cache encontrado para $(basename "$CPP_FILE"). Pulando captura da porta...${RESET}"
fi

JSON_FILE=$(< "$CACHE_FILE")

if [ -z "$JSON_FILE" ]; then
	echo -e "${RED}Error: Nenhum dado válido capturado${RESET}" >&2
	rm -f -- "$CACHE_FILE"
	exit 1
fi


# ---------------
# PARSING DO NOME
# ---------------
PROBLEM_NAME=$(echo "$JSON_FILE" | grep -o '"name":"[^"]*' | head -n 1 | sed 's/"name":"//')

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
TIME_LIMIT=$(printf '%s\n' "$JSON_FILE" | sed 's/,/\n/g' | grep '"timeLimit":' | head -n 1 | sed 's/"timeLimit":\([0-9]*\)/\1/')

echo -e "${WHITE}Problema: $PROBLEM_NAME | Tempo Limite: ${TIME_LIMIT}ms${RESET}"

# os comandos de dentro do awk não são interpretados pela bash
printf '%s' "$JSON_FILE" | awk -v tmp_dir="$TMP_DIR" '

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
	file_in = tmp_dir "/in" (NR-1) ".txt"
	file_out = tmp_dir "/out" (NR-1) ".txt"

	# grava os conteúdos sem adicinoar uma quebra de linha extra
	printf "%s", in_str > file_in
	printf "%s", out_str > file_out
}'

# se a expansão não existir, expande pro vazio ao invés de para a string literal
shopt -s nullglob

# armazena os arquivos de entrada encontrados
TEST_FILES=("$TMP_DIR"/in*.txt)
# conta quantos casos de teste foram gerados
TESTS_COUNT=${#TEST_FILES[@]}

if [ "$TESTS_COUNT" -eq 0 ]; then
	echo -e "${RED}Nenhum caso de teste foi gerado.${RESET}" >&2
	register_log "ERRO" "Nenhum caso de teste encontrado"
	exit 1
else
	echo -e "${CYAN}Foram gerados $TESTS_COUNT casos de teste locais a partir da plataforma${RESET}"
fi


# ---------------------------
# COMPILAÇÃO E LAÇOS DE TESTE
# ---------------------------
echo -e "${YELLOW}Iniciando a compilação do arquivo: $CPP_FILE...${RESET}"

# manda o erro de compilação (se houver) para o arquivo temporário comp_error.tmp
g++ -Wall -O2 "$CPP_FILE" -o "$EXEC_FILE" 2> "$COMP_ERROR" || { 
	echo -e "${RED}CE (Compilation Error)${RESET}" >&2
	COMP_ERROR_MSG=$(head -n 1 "$COMP_ERROR" | tr ',' ';')
	register_log "CE" "Erro: $COMP_ERROR_MSG"
	exit 1
}

echo -e "${YELLOW}Rodando testes locais...${RESET}"

# converte o tempo de ms para seg com 3 casas decimais
TIME_SEC=$(printf '%d.%03d' "$((TIME_LIMIT / 1000))" "$((TIME_LIMIT % 1000))")

FULL_PASS=1

# itera sobre todos os ficheiros de entrada
for in_file in "${TEST_FILES[@]}"; do
	# remove o caminho do diretório e o prefixo in e o sufixo .txt pra pegar só o numero do teste
	test_num="${in_file##*/}"
	test_num="${test_num#in}"
	test_num="${test_num%.txt}"

	out_file="$TMP_DIR/out${test_num}.txt"
	my_out="$TMP_DIR/my_out${test_num}.txt"
	run_error="$TMP_DIR/run_error${test_num}.txt"

	# executa o binário controlando o tempo e armazena a saída de erro
	# timeout dentro do condicional porque a flag -e fecha o programa se um processo retornar falha
	# precisa de dois comandos entre parenteses porque a shell não cria uma subshell se tiver somente um comando
	# subshell necessário para não imprimir saída de erro da bash no terminal 
	# se o timeout falhar, a subshell vai executar o exit e entregar o mesmo código de erro para o script
	if ( timeout -k 1s "${TIME_SEC}s" "$EXEC_FILE" < "$in_file" > "$my_out" || exit "$?" ) 2> "$run_error"; then
		exit_code=0
	else
		# pega o código de saída do binário ou do terminal quando não dá RTE
		exit_code="$?"
	fi

	echo -n "Teste $test_num: "

	# 137 também é considerado TLE pois pode ocorrer quando o timeout precisa utilizar o sinal sigkill depois do tempo adicional
	if [ "$exit_code" -eq 124 ] || [ "$exit_code" -eq 137 ]; then
		echo -e "${RED}TLE (Time Limit Exceeded)${RESET}"
		register_log "TLE" "Falha no Teste $test_num"
		FULL_PASS=0

	# mensagens de erro referentes à ferramenta, e não ao RTE ou ao AC
	elif [ "$exit_code" -eq 125 ] ||  [ "$exit_code" -eq 126 ] ||  [ "$exit_code" -eq 127 ]; then
		echo -e "${RED}Erro interno na execução do timeout ou do executável.${RESET}"
 
		# exibe as eventuais mensagens de erro 
		if [ -s "$run_error" ]; then
			cat "$run_error" >&2
		fi

		register_log "ERRO" "Falha interna na execução do teste $test_num"
		exit 1
	
	elif [ "$exit_code" -ne 0 ]; then
		echo -e "${RED}RTE (Runtime Error)${RESET}"
		
		# exibe as eventuais mensagens de erro 
		if [ -s "$run_error" ]; then
			sed -n '1p' "$run_error" >&2
		fi

		register_log "RTE" "Falha no Teste $test_num"
		FULL_PASS=0

	else
		# compara saídas ignorando diferenças de espaços em branco
		diff_file="$TMP_DIR/diff${test_num}.txt"

		# usa a flag -w pra ignorar diferencas de espacos em branco
		if diff -u -w --label "Saída esperada" --label "Sua saída" "$out_file" "$my_out" > "$diff_file"; then
			echo -e "${GREEN}Passou (AC local)${RESET}"
		else
			echo -e "${RED}WA (Wrong Answer)${RESET}"
			cat "$diff_file"
			register_log "WA" "Falha no Teste $test_num"
			FULL_PASS=0
		fi
	fi
done

if [ "$FULL_PASS" -eq 1 ]; then
	echo -e "${BOLD_GREEN}Todos os testes locais passaram com sucesso!${RESET}"
	register_log "AC Local" "Passou em todos os testes" 
fi