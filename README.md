English | [Português-BR](README.pt-br.md)

# Automatic Judge for Competitive Programming

A Shell Script CLI that integrates with [Competitive Companion](https://github.com/jmerle/competitive-companion) to automatically fetch test cases, test C++ solutions, and manage versioning with Git.

---

## Overview

The script automates part of the local competitive programming workflow: it receives problem data from Competitive Companion, extracts the time limit and test cases, compiles a C++ solution, runs the program for each test case, and compares the obtained output with the expected result.

### Execution flow

1. Receive the problem data sent by Competitive Companion.
2. Extract the problem name, time limit, and test cases.
3. Store the received data in cache for reuse.
4. Compile the C++ source file using `g++`.
5. Run the program for each test case, respecting the time limit with `timeout`.
6. Compare the obtained and expected outputs, ignoring whitespace differences.
7. Record the results in a CSV file.
8. Optionally, commit an already accepted solution to the local Git repository.

---

## Features

- **Automatic test retrieval:** receives test cases through a local port opened with Netcat.
- **Data parsing:** uses `awk`, `sed`, and `grep` to extract the necessary information from the received JSON.
- **Test case cache:** stores the received data in a JSON file to avoid fetching it again on every run.
- **C++ compilation:** compiles the source file using `g++`, with the `-Wall` and `-O2` options.
- **Time limit control:** limits the execution time of each test with `timeout`.
- **Output comparison:** uses `diff -w` to ignore whitespace differences.
- **Result classification:** identifies local acceptance (`AC Local`), wrong answer (`WA`), time limit exceeded (`TLE`), runtime error (`RTE`), and compilation error (`CE`).
- **CSV log:** records the date, source file, result, and additional information, keeping a format compatible with CSV readers.
- **Git integration:** optionally stages and commits a solution after it has been accepted by the online judge.

---

## Requirements

Developed for execution in a Linux environment.

- **Shell:** Bash
- **Compiler:** `g++`
- **Browser extension:** [Competitive Companion](https://github.com/jmerle/competitive-companion)
- **Utilities:** `nc` (Netcat), `timeout`, `diff`, `awk`, `sed`, `grep`, and standard Linux utilities.
- **Version control:** Git (needed only to use the `--ac` option).

To use the Git integration, run the script inside a Git repository.

---

## Usage

Grant execution permission to the script:

```bash
chmod +x judge.sh
```

Run it, passing the C++ source file:

```bash
./judge.sh solution.cpp
```

When there is no cached data for that file, the script opens a local listening port on port `10044`. Open the problem in your browser and use Competitive Companion to send the data to the script.

Then the program extracts the test cases, compiles the solution, and runs the tests.

**Note:** make sure port `10044` is available in the execution environment.

---

## Global Installation (Optional)

By default, the script can be executed directly by its path. However, it can also be added to the `PATH` to be used as a global command, without needing to keep `judge.sh` in the same directory as the source files.

On Linux, run the following commands in the directory where the script is located:

```bash
chmod +x judge.sh
mkdir -p ~/.local/bin
ln -sfn "$(realpath judge.sh)" ~/.local/bin/judge
```

Make sure `~/.local/bin` is in your `PATH`. For Bash users, if it is not already configured, run:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

After configuration, the command can be executed from any directory:

```bash
judge solution.cpp
judge --refresh solution.cpp
judge --ac solution.cpp
```

The symbolic link points to the original file, so changes to `judge.sh` are automatically reflected. If the original file is moved or deleted, the link must be updated.

**Important:** although the command can be executed from any directory, the Git integration requires the current working directory to be inside a Git repository.

---

## Options

The script accepts the following options:

| Option | Description |
|---|---|
| `--refresh` | Removes the problem data stored in cache and waits for a new submission from Competitive Companion. |
| `--ac` | Uses the cached data to identify the problem and commits the source file to the local Git repository. |

### Examples

Refresh the problem data:

```bash
./judge.sh --refresh solution.cpp
```

Record an already accepted solution:

```bash
./judge.sh --ac solution.cpp
```

**Warning:** the `--ac` option should only be used after the solution has been accepted by the online judge. It does not run compilation or local tests; its purpose is to record an already accepted solution in the repository history.

---

## Results and Logs

For each test case, the script reports one of the following results:

| Result | Meaning |
|---|---|
| `AC Local` | The test passed in the local comparison. |
| `WA` | The program output differs from the expected output. |
| `TLE` | The execution time limit was exceeded. |
| `RTE` | The program terminated with an error during execution. |
| `CE` | The C++ source file could not be compiled. |
| `ERRO` | An internal problem occurred during the judge execution. |

When all tests pass, the program reports that the solution was locally accepted and records the `AC Local` result in the log.

**Important:** `AC Local` indicates that the solution passed the locally available test cases. This does not, by itself, guarantee acceptance by the online judge, since there may be other test cases not provided by the platform.

### CSV File

Records are stored in `log.csv`, with the following columns:

| Column | Description |
|---|---|
| `data` | Date and time of execution. |
| `arquivo` | Name of the source file used. |
| `resultado` | Result obtained in the execution. |
| `detalhes` | Additional information about the result, when applicable. |

The file uses a header and always keeps the four columns, even when there is no additional information.

All fields are delimited by double quotes, and any quotes present in the values are doubled to preserve the CSV structure.

### Problem cache

Problem data is stored in hidden JSON files whose name uses the source file name and the `.cache_` prefix.

For example, for `solution.cpp`, the following will be created:

```text
.cache_solution.cpp.json
```

Use the `--refresh` option to discard the existing cache and fetch the data again.

**Note:** both the log file and the cache files are created in the current working directory, not necessarily in the directory where the script is installed.

---

## Git Integration

The `--ac` option should be used for solutions that have already been accepted by the online judge.

Before committing, the script checks whether Git is available and whether the current working directory belongs to a Git repository.

It then uses `git add` on the given source file and creates a commit whose message includes the file name and the problem name.

**Notes:**

- The `--ac` option does not run the tests nor verify the solution's acceptance by the online judge. This confirmation must be done by the user.
- The script runs `git add` and `git commit`, but does not run `git push`. The commit is created in the local repository and must be pushed separately to update a remote repository.

---

## Known Limitations

- **JSON parsing:** data interpretation is performed with traditional text processing tools such as `awk`, `sed`, and `grep`. The implementation considers the data format normally received from Competitive Companion, but it is not a complete JSON parser and may not correctly interpret all escape sequences provided by the format.
- **Output comparison:** the `diff -w` option ignores whitespace differences. This is suitable for the usual answer comparison in competitive programming, but may not be appropriate for problems where whitespace is part of the expected content.
- **Resource limits:** the script controls the execution time of each test, but does not implement a memory consumption limit.
- **Cache:** cache files use the source file name as an identifier. Files with the same name, used in the same working directory, may share the same cache.

---

## Authorship

**Developed by:** Giovanni Estevam dos Santos  
**GitHub:** [mavettse](https://github.com/mavettse)