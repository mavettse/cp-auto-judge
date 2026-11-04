[English](README.md) | Português-BR

# Judge Automático para Programação Competitiva

Uma CLI em Shell Script que integra com o [Competitive Companion](https://github.com/jmerle/competitive-companion) para obter casos de teste automaticamente, testar soluções em C++ e gerenciar o versionamento com Git.

---

## Visão Geral

O script automatiza parte do fluxo de trabalho local da programação competitiva: recebe os dados do problema pelo Competitive Companion, extrai o limite de tempo e os casos de teste, compila uma solução em C++, executa o programa para cada caso e compara a saída obtida com o resultado esperado.

### Fluxo de execução

1. Receber os dados do problema enviados pelo Competitive Companion.
2. Extrair o nome do problema, o limite de tempo e os casos de teste.
3. Armazenar os dados recebidos em cache para reutilização.
4. Compilar o arquivo-fonte em C++ utilizando `g++`.
5. Executar o programa para cada caso de teste, respeitando o limite de tempo com `timeout`.
6. Comparar as saídas obtidas e esperadas, ignorando diferenças em espaços em branco.
7. Registrar os resultados em um arquivo CSV.
8. Opcionalmente, realizar o commit de uma solução já aceita no repositório Git local.

---

## Funcionalidades

- **Obtenção automática dos testes:** recebe os casos de teste por meio de uma porta local aberta com Netcat.
- **Parsing dos dados:** utiliza `awk`, `sed` e `grep` para extrair as informações necessárias do JSON recebido.
- **Cache dos casos de teste:** armazena os dados recebidos em um arquivo JSON para evitar uma nova captura a cada execução.
- **Compilação em C++:** compila o arquivo-fonte utilizando `g++`, com as opções `-Wall` e `-O2`.
- **Controle do limite de tempo:** limita o tempo de execução de cada teste com `timeout`.
- **Comparação de saídas:** utiliza `diff -w` para ignorar diferenças em espaços em branco.
- **Classificação dos resultados:** identifica aprovação local (`AC Local`), resposta incorreta (`WA`), tempo excedido (`TLE`), erro em tempo de execução (`RTE`) e erro de compilação (`CE`).
- **Log em CSV:** registra a data, o arquivo-fonte, o resultado e informações adicionais, mantendo um formato compatível com leitores de CSV.
- **Integração com Git:** opcionalmente adiciona e realiza o commit de uma solução após sua aceitação no juiz online.

---

## Requisitos

Desenvolvido para execução em ambiente Linux.

- **Shell:** Bash
- **Compilador:** `g++`
- **Extensão de navegador:** [Competitive Companion](https://github.com/jmerle/competitive-companion)
- **Utilitários:** `nc` (Netcat), `timeout`, `diff`, `awk`, `sed`, `grep` e utilitários padrão do Linux.
- **Versionamento:** Git (necessário apenas para utilizar a opção `--ac`).

Para utilizar a integração com Git, execute o script dentro de um repositório Git.

---

## Utilização

Conceda permissão de execução ao script:

```bash
chmod +x judge.sh
```

Execute-o informando o arquivo-fonte em C++:

```bash
./judge.sh solution.cpp
```

Quando não há dados em cache para aquele arquivo, o script abre uma porta de escuta local na porta `10044`. Abra o problema no navegador e utilize o Competitive Companion para enviar os dados ao script.

Em seguida, o programa extrai os casos de teste, compila a solução e executa os testes.

**Observação:** certifique-se de que a porta `10044` esteja disponível no ambiente de execução.

---

## Instalação Global (Opcional)

Por padrão, o script pode ser executado diretamente pelo seu caminho. Entretanto, também é possível adicioná-lo ao `PATH` para utilizá-lo como um comando global, sem precisar manter `judge.sh` no mesmo diretório dos arquivos-fonte.

No Linux, execute os comandos abaixo no diretório em que está localizado o script:

```bash
chmod +x judge.sh
mkdir -p ~/.local/bin
ln -sfn "$(realpath judge.sh)" ~/.local/bin/judge
```

Certifique-se de que `~/.local/bin` esteja no `PATH`. Para usuários do Bash, caso ainda não esteja configurado, execute:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Após a configuração, o comando poderá ser executado de qualquer diretório:

```bash
judge solution.cpp
judge --refresh solution.cpp
judge --ac solution.cpp
```

O link simbólico aponta para o arquivo original, portanto, alterações no `judge.sh` são refletidas automaticamente. Caso o arquivo original seja movido ou removido, será necessário atualizar o link.

**Importante:** embora o comando possa ser executado de qualquer diretório, a integração com Git exige que o diretório de trabalho atual esteja dentro de um repositório Git.

---

## Opções

O script aceita as seguintes opções:

| Opção | Descrição |
|---|---|
| `--refresh` | Remove os dados do problema armazenados em cache e aguarda um novo envio do Competitive Companion. |
| `--ac` | Utiliza os dados em cache para identificar o problema e realiza o commit do arquivo-fonte no repositório Git local. |

### Exemplos

Atualizar os dados do problema:

```bash
./judge.sh --refresh solution.cpp
```

Registrar uma solução já aceita:

```bash
./judge.sh --ac solution.cpp
```

**Atenção:** a opção `--ac` deve ser utilizada somente após a aceitação da solução no juiz online. Ela não executa a compilação nem os testes locais; sua finalidade é registrar uma solução já aceita no histórico do repositório.

---

## Resultados e Logs

Para cada caso de teste, o script informa um dos seguintes resultados:

| Resultado | Significado |
|---|---|
| `AC Local` | O teste passou na comparação local. |
| `WA` | A saída do programa é diferente da saída esperada. |
| `TLE` | O tempo limite de execução foi excedido. |
| `RTE` | O programa terminou com um erro durante a execução. |
| `CE` | Não foi possível compilar o arquivo-fonte em C++. |
| `ERRO` | Ocorreu um problema interno durante a execução do juiz. |

Quando todos os testes passam, o programa informa que a solução foi aprovada localmente e registra o resultado `AC Local` no log.

**Importante:** `AC Local` indica que a solução passou pelos casos de teste disponíveis localmente. Isso não garante, por si só, a aceitação pelo juiz online, pois podem existir outros casos de teste não disponibilizados pela plataforma.

### Arquivo CSV

Os registros são armazenados em `log.csv`, com as seguintes colunas:

| Coluna | Descrição |
|---|---|
| `data` | Data e horário da execução. |
| `arquivo` | Nome do arquivo-fonte utilizado. |
| `resultado` | Resultado obtido na execução. |
| `detalhes` | Informações adicionais sobre o resultado, quando aplicável. |

O arquivo utiliza um cabeçalho e mantém sempre as quatro colunas, mesmo quando não há informações adicionais.

Todos os campos são delimitados por aspas duplas, e eventuais aspas presentes nos valores são duplicadas para preservar a estrutura do CSV.

### Cache dos problemas

Os dados dos problemas são armazenados em arquivos JSON ocultos, cujo nome utiliza o nome do arquivo-fonte e o prefixo `.cache_`.

Por exemplo, para `solution.cpp`, será criado:

```text
.cache_solution.cpp.json
```

Utilize a opção `--refresh` para descartar o cache existente e obter os dados novamente.

**Observação:** tanto o arquivo de log quanto os arquivos de cache são criados no diretório de trabalho atual, e não necessariamente no diretório em que o script está instalado.

---

## Integração com Git

A opção `--ac` deve ser utilizada para soluções que já foram aceitas pelo juiz online.

Antes de realizar o commit, o script verifica se o Git está disponível e se o diretório de trabalho atual pertence a um repositório Git.

Em seguida, utiliza `git add` no arquivo-fonte informado e cria um commit cuja mensagem inclui o nome do arquivo e o nome do problema.

**Observações:**

- A opção `--ac` não executa os testes nem verifica a aceitação da solução no juiz online. Essa confirmação deve ser feita pelo usuário.
- O script executa `git add` e `git commit`, mas não executa `git push`. O commit é criado no repositório local e deve ser enviado separadamente para atualizar um repositório remoto.

---

## Limitações Conhecidas

- **Parsing do JSON:** a interpretação dos dados é realizada com ferramentas tradicionais de processamento de texto, como `awk`, `sed` e `grep`. A implementação considera o formato de dados normalmente recebido do Competitive Companion, mas não constitui um parser JSON completo e pode não interpretar corretamente todas as sequências de escape previstas pelo formato.
- **Comparação de saídas:** a opção `diff -w` ignora diferenças em espaços em branco. Isso é adequado para a comparação usual de respostas em programação competitiva, mas pode não ser apropriado para problemas em que os espaços façam parte do conteúdo esperado.
- **Limite de recursos:** o script controla o tempo de execução de cada teste, mas não implementa um limite de consumo de memória.
- **Cache:** os arquivos de cache utilizam o nome do arquivo-fonte como identificador. Arquivos com o mesmo nome, utilizados no mesmo diretório de trabalho, podem compartilhar o mesmo cache.

---

## Autoria

**Desenvolvido por:** Giovanni Estevam dos Santos  
**GitHub:** [mavettse](https://github.com/mavettse)