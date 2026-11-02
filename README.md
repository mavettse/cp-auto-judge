English \| [Português-BR](README.pt-br.md)

# Competitive Programming Judge

A lightweight shell CLI that integrates with [Competitive
Companion](https://github.com/jmerle/competitive-companion) to
automatically fetch test cases, test C++ solutions, and handle Git
versioning.

------------------------------------------------------------------------

## Overview

The script automates part of the local competitive programming workflow:
it receives problem data from Competitive Companion, extracts the time
limit and test cases, compiles a C++ solution, runs it against each test
case, and compares the output with the expected result.

### Workflow

1.  Receive problem data sent by Competitive Companion.
2.  Extract the problem name, time limit, and test cases.
3.  Compile the selected C++ source file with `g++`.
4.  Run the executable for each test case, enforcing the time limit with
    `timeout`.
5.  Compare actual and expected outputs, ignoring whitespace
    differences.
6.  Record results in a CSV log.
7.  Optionally commit an already accepted solution to the local Git
    repository.

------------------------------------------------------------------------

## Features

-   **Automatic test retrieval:** receives test cases through a local
    Netcat listener.
-   **C++ compilation:** compiles the selected source file using `g++`.
-   **Time limit enforcement:** limits each test execution with
    `timeout`.
-   **Output comparison:** uses `diff -w` to ignore whitespace
    differences.
-   **Result classification:** reports compilation errors (`CE`), wrong
    answers (`WA`), time limit exceeded (`TLE`), and runtime errors
    (`RTE`).
-   **Test case cache:** stores received problem data in a JSON file to
    avoid fetching it again on every run.
-   **CSV log:** records the date, source file, result, and additional
    details.
-   **Git integration:** optionally stages and commits a solution after
    it has been accepted by the online judge.

------------------------------------------------------------------------

## Requirements

Designed for Linux environments.

-   **Shell:** Bash
-   **Compiler:** `g++`
-   **Browser extension:** [Competitive
    Companion](https://github.com/jmerle/competitive-companion)
-   **Utilities:** `nc` (Netcat), `timeout`, `diff`, `sed`, `grep`,
    `awk`, `date`, and standard command-line tools
-   **Version control:** Git

Run the script inside a Git repository if you intend to use the Git
integration.

------------------------------------------------------------------------

## Usage

Grant execution permission:

``` bash
chmod +x judge.sh
```

Run the script with a C++ source file:

``` bash
./judge.sh solution.cpp
```

If no cached data exists for that source file, the script opens a local
listener on port `10044`. Open the problem in your browser and use
Competitive Companion to send its data to the script. It then extracts
the test cases, compiles the solution, and runs the tests.

### Options

  -----------------------------------------------------------------------
  Option                              Description
  ----------------------------------- -----------------------------------
  `--refresh`                         Removes cached problem data and
                                      waits for a new submission from
                                      Competitive Companion.

  `--ac`                              Uses the problem data to identify
                                      the problem and commits the source
                                      file to the local Git repository.
                                      Intended for solutions already
                                      accepted by the online judge.
  -----------------------------------------------------------------------

Examples:

``` bash
./judge.sh --refresh solution.cpp
./judge.sh --ac solution.cpp
```

------------------------------------------------------------------------

## Results and Logs

The script reports one of the following results for each test case:

  Result   Meaning
  -------- ------------------------------------------------------
  `AC`     The test passed.
  `WA`     The program output differs from the expected output.
  `TLE`    The execution exceeded the time limit.
  `RTE`    The program terminated with a runtime error.
  `CE`     The C++ source file could not be compiled.

Execution records are stored in `log.csv`, including the date, source
file, result, and additional details when applicable.

Problem data is cached in a hidden JSON file named using the source
filename and the `.cache_` prefix. Use `--refresh` to discard the cache
and retrieve the data again.

------------------------------------------------------------------------

## Git Integration

The `--ac` option is intended for solutions that have already been
accepted by the online judge. It runs `git add` on the specified source
file and creates a commit whose message includes the filename and
problem name.

**Note:** the script runs `git add` and `git commit`; it does not run
`git push`. The commit is created locally and must be pushed separately
to update a remote repository.

------------------------------------------------------------------------

## Author

**Developed by:** Giovanni Estevam dos Santos\
**GitHub:** [mavettse](https://github.com/mavettse)
