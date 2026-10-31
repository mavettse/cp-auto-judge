#!/bin/bash

# -e: para a execução se algum comando falhar
# -u: acusa erro se tentar usar variável não inicializada
# -o: garante que erros em pipes não sejam ocultados
set -euo pipefail

# ----------------------------------
# DEFINIÇÃO DE VARIÁVEIS E ATRIBUTOS
# ----------------------------------
declare -i NC_PORT=10044
declare -r LOG_FILE="log.csv"
AC_MODE=0
CPP_FILE=""


# -------------------------------
# VALIDAÇÃO E PARSE DE PARÂMETROS
# -------------------------------
if [ "$#" -eq 0 ]; then
	echo "Uso: $0 [--ac] <caminho/para/arquivo.cpp>" >&2
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
			echo "Erro: Parâmetro não conhecido '$1'." >&2
			exit 1
			;;
	esac
done

# se a string estiver vazia
if [ -z "$CPP_FILE" ]; then
	echo "Nenhum arquivo .cpp foi encontrado" >&2
	exit 1
fi

# cria o arquivo de log, se ele não existir
if [ ! -f "$LOG_FILE" ]; then
	touch "$LOG_FILE"
fi


# ------------------------------------------
# ABERTURA DA PORTA PARA RECEBIMENTO DO JSON
# ------------------------------------------
if [ "$AC_MODE" -eq 0 ]; then
	echo "Aguardando o envio do Competitive Companion na porta $NC_PORT..."

	# suprime a entrada, guardando somente a partir do { (onde começa o json)
# REATIVAR NOVAMENTE!!!!
# 	JSON_FILE="$(nc -l -p $NC_PORT | sed -n '/{/ p')"
# EXCLUIR LINHA ABAIXO QUANDO REATIVAR A DE CIMA
	JSON_FILE="$(cat "json_file.txt")"

	# checa se a entrada não capturou nada da porta
	if [ -z "$JSON_FILE" ]; then
		echo "Erro: Nenhum dado capturado na porta $NC_PORT." >&2
		exit 1
	fi


# -----------------
# PARSING DOS DADOS
# -----------------
	PROBLEM_NAME=$(echo -n $JSON_FILE | sed -n 's/.*name":"\([^"]*\).*/\1/p')
	PROBLEM_ID=$(echo -n $JSON_FILE | sed 's/,/\n/g' | grep '"url":"' | sed -n 's/.*\/\([0-9]*\).*/\1/p')
	TIME_LIMIT=$(echo -n $JSON_FILE | sed 's/,/\n/g' | grep '"timeLimit":' | sed 's/"timeLimit":\([0-9]*\)/\1/')

	echo "Problema: $PROBLEM_ID - $PROBLEM_NAME | Tempo Limite: ${TIME_LIMIT}ms"

	rm -f in*.txt out*.txt

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
	echo "Foram gerados $TESTS_COUNT casos de teste locais a partir da plataforma"
fi


# ---------------------------
# COMPILAÇÃO E LAÇOS DE TESTE
# ---------------------------
echo "Iniciando a compilação do arquivo: $CPP_FILE..."

g++ -Wall -O2 "$CPP_FILE" -o exec_file || {
	echo "CE (Compilation Error)" >&2
	exit 1
}

echo "Rodando testes locais..."

# converte o tempo de ms para seg (coloca um tempo minimo de 1 seg  senao nao funciona kkkk
TIME_SEC=$(( TIME_LIMIT/1000 ))
if [ "$TIME_SEC" -eq 0 ]; then
	TIME_SEC=1
fi

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
		echo "TLE (Time Limit Exceeded"
	elif [ "$exit_code" -ne 0 ]; then
		echo "RTE (Runtime Error"
	else
		# usa a flag -w pra ignorar diferencas de espacos em branco
		if diff -w "$out_file" "$my_out" > /dev/null 2>&1; then
			echo "Passou (AC local)"
		else
			echo "WA (Wrong Answer)"
		fi
	fi
done

# remove os arquivos criados
rm -f exec_file my_out*.txt out*.txt in*.txt










