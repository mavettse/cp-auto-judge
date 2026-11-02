[English](README.md) \| Português-BR

# Judge Automático para Programação Competitiva

Uma CLI em Shell Script que integra com o [Competitive
Companion](https://github.com/jmerle/competitive-companion) para obter
casos de teste automaticamente, testar soluções em C++ e gerenciar o
versionamento com Git.

------------------------------------------------------------------------

## Visão Geral

O script automatiza parte do fluxo de trabalho local da programação
competitiva: recebe os dados do problema pelo Competitive Companion,
extrai o limite de tempo e os casos de teste, compila uma solução em
C++, executa o programa para cada caso e compara a saída obtida com o
resultado esperado.

### Fluxo de execução

1.  Receber os dados do problema enviados pelo Competitive Companion.
2.  Extrair o nome do problema, o limite de tempo e os casos de teste.
3.  Compilar o arquivo-fonte em C++ utilizando `g++`.
4.  Executar o programa para cada caso de teste, respeitando o limite de
    tempo com `timeout`.
5.  Comparar as saídas obtidas e esperadas, ignorando diferenças de
    espaços em branco.
6.  Registrar os resultados em um arquivo CSV.
7.  Opcionalmente, realizar o commit de uma solução já aceita no
    repositório Git local.

------------------------------------------------------------------------

## Funcionalidades

-   **Obtenção automática dos testes:** recebe os casos de teste por
    meio de uma porta local aberta com Netcat.
-   **Compilação em C++:** compila o arquivo-fonte selecionado
    utilizando `g++`.
-   **Controle do limite de tempo:** limita o tempo de execução de cada
    teste com `timeout`.
-   **Comparação de saídas:** utiliza `diff -w` para ignorar diferenças
    de espaços em branco.
-   **Classificação dos resultados:** informa erro de compilação (`CE`),
    resposta incorreta (`WA`), tempo excedido (`TLE`) e erro em tempo de
    execução (`RTE`).
-   **Cache dos casos de teste:** armazena os dados recebidos em um
    arquivo JSON para evitar uma nova captura a cada execução.
-   **Log em CSV:** registra data, arquivo-fonte, resultado e
    informações adicionais.
-   **Integração com Git:** opcionalmente adiciona e realiza o commit de
    uma solução após sua aceitação no juiz online.

------------------------------------------------------------------------

## Requisitos

Desenvolvido para execução em ambiente Linux.

-   **Shell:** Bash
-   **Compilador:** `g++`
-   **Extensão de navegador:** [Competitive
    Companion](https://github.com/jmerle/competitive-companion)
-   **Utilitários:** `nc` (Netcat), `timeout`, `diff`, `sed`, `grep`,
    `awk`, `date` e comandos padrão de linha de comando
-   **Versionamento:** Git

Para utilizar a integração com Git, execute o script dentro de um
repositório Git.

------------------------------------------------------------------------

## Utilização

Conceda permissão de execução ao script:

``` bash
chmod +x judge.sh
```

Execute-o informando o arquivo-fonte em C++:

``` bash
./judge.sh solution.cpp
```

Quando não há dados em cache para aquele arquivo, o script abre uma
porta de escuta local na porta `10044`. Abra o problema no navegador e
utilize o Competitive Companion para enviar os dados ao script. Em
seguida, ele extrai os casos de teste, compila a solução e executa os
testes.

------------------------------------------------------------------------

## Instalação Global (Opcional)

Por padrão, o script pode ser executado diretamente pelo seu caminho.
Entretanto, também é possível adicioná-lo ao `PATH` para utilizá-lo
como um comando global, sem precisar manter `judge.sh` no mesmo
diretório dos arquivos-fonte.

No Linux, execute os comandos abaixo no diretório em que está
localizado o script:

```bash
chmod +x judge.sh
mkdir -p ~/.local/bin
ln -sfn "$(realpath judge.sh)" ~/.local/bin/judge
```

Certifique-se de que ~/.local/bin esteja no PATH. Para usuários
do Bash, caso ainda não esteja configurado, execute:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Após a configuração, o script poderá ser executado de qualquer diretório:

```bash
judge solution.cpp
judge --refresh solution.cpp
judge --ac solution.cpp
```

O link simbólico aponta para o arquivo original, portanto, alterações
no judge.sh são refletidas automaticamente. Caso o arquivo original
seja movido ou removido, será necessário atualizar o link.

------------------------------------------------------------------------

## Opções

- `--refresh`: Remove os dados do problema armazenados em cache e 
aguarda um novo envio do Competitive Companion.
- `--ac`: Utiliza os dados em cache para identificar o problema e, em 
seguida, adiciona o arquivo-fonte ao Git e cria um commit no 
repositório local. Deve ser utilizada para soluções que já foram 
aceitas pelo juiz online.

Exemplos:

```bash
./judge.sh --refresh solution.cpp
./judge.sh --ac solution.cpp
```

------------------------------------------------------------------------

## Resultados e Logs

Para cada caso de teste, o script informa um dos seguintes resultados:

| Resultado | Significado |
|---|---|
| `AC` | O teste passou. |
| `WA` | A saída do programa é diferente da saída esperada. |
| `TLE` | O tempo limite de execução foi excedido. |
| `RTE` | O programa terminou com um erro durante a execução. |
| `CE` | Não foi possível compilar o arquivo-fonte em C++. |

Os registros das execuções são armazenados em `log.csv`, incluindo data,
arquivo-fonte, resultado e informações adicionais, quando aplicável.

Os dados do problema são armazenados em cache em um arquivo JSON oculto,
cujo nome utiliza o nome do arquivo-fonte e o prefixo `.cache_`. Utilize
`--refresh` para descartar o cache e obter os dados novamente.

------------------------------------------------------------------------

## Integração com Git

A opção `--ac` deve ser utilizada para soluções que já foram aceitas
pelo juiz online. Ela executa `git add` no arquivo-fonte informado e
cria um commit cuja mensagem inclui o nome do arquivo e o nome do
problema.

**Observação:** o script executa `git add` e `git commit`, mas não
executa `git push`. O commit é criado no repositório local e deve ser
enviado separadamente para atualizar um repositório remoto.

------------------------------------------------------------------------

## Autoria

**Desenvolvido por:** Giovanni Estevam dos Santos\
**GitHub:** [mavettse](https://github.com/mavettse)
