# Meta-Meta Artifact

## Table of Contents

- [1. Installation](#1-installation)
  - [Option 1: Build the Docker image](#option-1-build-the-docker-image)
  - [Option 2: Pull the Docker image from DockerHub](#option-2-pull-the-docker-image-from-dockerhub)
  - [Option 3: Build from source on Ubuntu 24.04](#option-3-build-from-source-on-ubuntu-2404)
- [2. File structure](#2-file-structure)
- [3. Evaluation](#3-evaluation)
  - [Building](#building)
  - [Test suites](#test-suites)
  - [Running a single program](#running-a-single-program)
    - [P4-SpecTec script](#p4-spectec-script)
    - [P4 type checking](#p4-type-checking)
    - [P4 simulation](#p4-simulation)
  - [Meta-execution of P4^P4ST](#meta-execution-of-p4p4st)
  - [Meta-meta-execution of P4ST^P4ST](#meta-meta-execution-of-p4stp4st)
  - [Meta-meta-execution of P4ST^Redex and P4ST^K](#meta-meta-execution-of-p4stredex-and-p4stk)
  - [Grouped P4 type checking and simulation](#grouped-p4-type-checking-and-simulation)
  - [P4ST^P4ST coverage](#p4stp4st-coverage)
  - [Reproducing Tables 1, 2, and 3](#reproducing-tables-1-2-and-3)
    - [Selecting the logs of each suite](#selecting-the-logs-of-each-suite)
    - [Selecting the coverage reports of each row](#selecting-the-coverage-reports-of-each-row)

## 1. Installation

Choose one of the three options below.
Options 1 and 2 require Docker; option 1 also requires BuildKit, the default builder since Docker Engine 23.0.

> [!NOTE]
> The artifact supports architectures x86_64 (amd64) and ARM64 (arm64).
> On ARM64, the artifact comes without the K framework, which only supports x86_64 Linux-like systems, so P4ST^K is unavailable.
> Everything else, including P4ST^P4ST and P4ST^Redex, works as on x86_64.

### Option 1: Build the Docker image

Build the image from the repository root and open a shell in a container.

```sh
# clone the artifact repository
git clone <URL>

# build an image from Dockerfile
docker build -t meta-artifact:latest .

# launch a docker container in detached state
docker run -dit --name artifact meta-artifact

# run a shell inside the container
docker exec -it artifact bash
```

The image build compiles the Rust implementation, the test drivers, and the meta specifications,
so every command in Evaluation runs without further builds.
You may download the Racket 9.3 installer for Linux from [here](https://download.racket-lang.org/racket-v9.3.html)
to skip downloading it during the build;
place `racket-9.3-x86_64-linux-buster-cs.sh` (x86_64) or `racket-9.3-aarch64-linux-buster-cs.sh` (ARM64)
at the repository root before building.

### Option 2: Pull the Docker image from DockerHub

<!-- TODO: fill in the DockerHub account once the image is published -->

```sh
# pull the image from DockerHub
docker pull <TODO>/meta-artifact:latest

# launch a docker container in detached state
docker run -dit --name artifact <TODO>/meta-artifact:latest

# run a shell inside the container
docker exec -it artifact bash
```

### Option 3: Build from source on Ubuntu 24.04

Run the commands below from the repository root.

a. Install the dependencies and build the artifact.

```sh
# clone the artifact repository
git clone <URL>

# install system packages
sudo apt-get update
sudo apt-get install -y ca-certificates curl build-essential pkg-config python3

# install rustup and the Rust toolchain pinned in p4spectec/rust-toolchain.toml
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none
. "$HOME/.cargo/env"
(cd p4spectec && rustup toolchain install)

# build the Rust implementation and the test drivers
make build metacirc
(cd p4spectec && cargo build --locked --release --manifest-path test-driver/Cargo.toml --target-dir target --bins)
```

b. Install Racket 9.3 with PLT Redex, and compile `spec-meta-redex`.

```sh
# install Racket 9.3 into /opt/racket
curl -fSL -o racket.sh https://download.racket-lang.org/releases/9.3/installers/racket-9.3-x86_64-linux-buster-cs.sh
echo "30dc59d9b5af083eacf793253d35782c5231e8bfb7a7331fe32ccd9a41fd792f  racket.sh" | sha256sum -c -
sudo sh racket.sh --in-place --dest /opt/racket < /dev/null
rm racket.sh
export PATH="/opt/racket/bin:$PATH"

# compile spec-meta-redex
make redex
```

On ARM64, install `racket-9.3-aarch64-linux-buster-cs.sh` with SHA256
`26e4d1c3bf8954c4413fb6737af5d211d44c1e158e34e4c90e0af1cde6353c9a` instead.

c. Install the K framework v7.1.337, and compile `spec-meta-k`.

This step is for x86_64 only; K does not support ARM64.

```sh
# install the K framework 7.1.337 and z3
curl -fSL -o kframework.deb https://github.com/runtimeverification/k/releases/download/v7.1.337/kframework_7.1.337_amd64_ubuntu_noble.deb
echo "3692997e6bfa4be490d24bd9201289d4a05872889c9da725dda21e99d03d6990  kframework.deb" | sha256sum -c -
sudo apt-get install -y ./kframework.deb z3
rm kframework.deb

# compile spec-meta-k
make kompile
```

Add `/opt/racket/bin` to `PATH` in your shell profile to keep it in new shells.

## 2. File structure

The tree below shows the artifact in the Docker container (options 1 and 2).
For option 3, the same structure is at the repository root instead of `/meta/`.

```
/meta/
├── p4spectec/                 # Rust implementation of meta-meta execution, built on top of P4-SpecTec
│   ├── src/                   # P4-SpecTec, with metacircular towers in src/metacirc/
│   └── test-driver/           # Test drivers, with test suite registrations (suites/) and expected results (expected/)
├── spec/                      # P4^P4ST: the P4 specification from P4-SpecTec
├── spec-meta/                 # P4ST^P4ST: the P4-SpecTec AL specification in P4-SpecTec
├── spec-meta-redex/           # P4ST^Redex: the P4-SpecTec AL specification in PLT Redex
├── spec-meta-redex-detcheck/  # P4ST^Redex with the determinism check of clauses and rules enabled
├── spec-meta-k/               # P4ST^K: the P4-SpecTec AL specification in K
├── spec-meta-k-detcheck/      # P4ST^K with the determinism check of clauses and rules enabled
├── towers/                    # Tower configurations running P4^P4ST or P4-SpecTec scripts on P4ST^P4ST, P4ST^Redex, or P4ST^K
├── p4c/                       # P4 include files (p4include/) and test programs (testdata/) from p4c
├── testdata/                  # P4-SpecTec scripts testing P4ST^P4ST (spec-meta/), and STF tests from P4-SpecTec (p4testgen/)
├── excludes/                  # Excluded tests from P4-SpecTec, and the folders splitting the grouped tests (metacirc-groups/)
├── patches/                   # Patched STF tests from P4-SpecTec
├── docs/                      # P4 specification documents from P4-SpecTec
├── scripts/                   # Scripts printing statistics of spec-meta-redex and spec-meta-k (stat/), and the tables of the paper from the logs and coverage reports (evaluation/)
└── logs/                      # Logs recorded by our runs; TEST_LOG=logs also writes here
```

## 3. Evaluation

Run every command from `/meta` in the container, or from the repository root for option 3.

### Building

The installation already builds everything below.
Rebuild with these commands after modifying the implementation or the specifications.

```sh
# build the P4-SpecTec binary bin/p4spectec
make
# build the meta-meta execution binary bin/metacirc
make metacirc
# build bin/metacirc, and compile spec-meta-k and spec-meta-k-detcheck
make kompile
# build bin/metacirc, and compile spec-meta-redex and spec-meta-redex-detcheck
make redex
# remove the binaries, the compiled meta specifications, and the Rust build outputs
make clean
```

The test drivers are built automatically when a test command runs.

### Test suites

The script suites run each P4-SpecTec script (`.watsup`) testing the behavior of P4ST^P4ST
that P4^P4ST does not reach.
A script enters at the relation `Main` or the function `$main`.
Scripts in `spec-meta-rel-err` are intended to fail.

| suite | expected outcome | P4-SpecTec scripts |
|---|---|---|
| `spec-meta-rel-succ` | success | `testdata/spec-meta/rel/succ/` |
| `spec-meta-rel-err` | failure | `testdata/spec-meta/rel/err/` |
| `spec-meta-func-succ` | success | `testdata/spec-meta/func/succ/` |

The type-checking suites type-check (`Program_ok`) each P4 program.
Programs listed in `excludes/static/` are skipped.

| suite | P4 programs |
|---|---|
| `run-positive` | `p4c/testdata/p4_16_samples/` |
| `run-negative` | `p4c/testdata/p4_16_errors/` |

The simulation suites run the STF packet tests of each P4 program of
`p4c/testdata/p4_16_samples/` for its architecture.
Tests listed in `excludes/static/` and `excludes/dynamic/` are skipped.

| suite | architecture | STF tests |
|---|---|---|
| `ebpf-p4c` | ebpf | `p4c/testdata/p4_16_samples/` |
| `ebpf-p4testgen` | ebpf | `testdata/p4testgen/` |
| `v1model-p4c` | v1model | `p4c/testdata/p4_16_samples/` |
| `v1model-p4testgen` | v1model | `testdata/p4testgen/` |
| `psa-p4c` | psa | `p4c/testdata/p4_16_samples/` |

### Running a single program

The `metacirc` binary runs a single P4-SpecTec script, P4 program, or STF test through a tower.
For installation option 3, either add the `bin` folder of the repository root to `PATH`,
or run it as `./bin/metacirc` instead of `metacirc`.

Run `metacirc run-meta --help` or `metacirc sim --help` for the full list of options.

#### P4-SpecTec script

```sh
metacirc run-meta -p <SCRIPT> <CONFIG>
```

- `<SCRIPT>`: the P4-SpecTec script to run.
- `<CONFIG>`: the tower configuration. For a script entering at the relation `Main`,
  use `towers/al-rel.json`, `towers/redex-detcheck.json`, or `towers/k-detcheck.json`
  to run on P4ST^P4ST, P4ST^Redex, or P4ST^K, respectively.
  For a script entering at the function `$main`, use `towers/al-func.json`,
  `towers/redex-detcheck-func.json`, or `towers/k-detcheck-func.json` instead.

```sh
# P4ST^P4ST
metacirc run-meta -p testdata/spec-meta/rel/succ/exp-iter.watsup towers/al-rel.json
# P4ST^Redex
metacirc run-meta -p testdata/spec-meta/rel/succ/exp-iter.watsup towers/redex-detcheck.json
# P4ST^K
metacirc run-meta -p testdata/spec-meta/func/succ/entry-func.watsup towers/k-detcheck-func.json
```

#### P4 type checking

```sh
metacirc run-meta -i <INCLUDE> -p <PROGRAM> <CONFIG>
```

- `<INCLUDE>`: the include path of the P4 program. The artifact provides `p4c/p4include`.
- `<PROGRAM>`: the P4 program to type-check.
- `<CONFIG>`: the tower configuration. Use `towers/al-p4-ok.json`, `towers/redex-p4-ok.json`,
  or `towers/k-p4-ok.json` to run on P4ST^P4ST, P4ST^Redex, or P4ST^K, respectively.

```sh
# P4ST^P4ST
metacirc run-meta -i p4c/p4include -p p4c/testdata/p4_16_samples/action-bind.p4 towers/al-p4-ok.json
# P4ST^Redex
metacirc run-meta -i p4c/p4include -p p4c/testdata/p4_16_samples/action-bind.p4 towers/redex-p4-ok.json
# P4ST^K
metacirc run-meta -i p4c/p4include -p p4c/testdata/p4_16_samples/action-bind.p4 towers/k-p4-ok.json
```

#### P4 simulation

```sh
metacirc sim --arch <ARCH> -i <INCLUDE> -p <PROGRAM> --stf <STF> <CONFIG>
```

- `<ARCH>`: the architecture of the P4 program, one of `ebpf`, `v1model`, or `psa`.
- `<INCLUDE>`: the include path of the P4 program. The artifact provides `p4c/p4include`.
- `<PROGRAM>`: the P4 program to simulate.
- `<STF>`: the STF test to run on the P4 program.
- `<CONFIG>`: the tower configuration. Use `towers/al-p4.json`, `towers/redex-p4.json`,
  or `towers/k-p4.json` to run on P4ST^P4ST, P4ST^Redex, or P4ST^K, respectively.

```sh
# P4ST^P4ST
metacirc sim --arch psa -i p4c/p4include -p p4c/testdata/p4_16_samples/hash-extern-bmv2.p4 --stf p4c/testdata/p4_16_samples/hash-extern-bmv2.stf towers/al-p4.json
# P4ST^Redex
metacirc sim --arch ebpf -i p4c/p4include -p p4c/testdata/p4_16_samples/action_call_ebpf.p4 --stf p4c/testdata/p4_16_samples/action_call_ebpf.stf towers/redex-p4.json
# P4ST^K
metacirc sim --arch v1model -i p4c/p4include -p p4c/testdata/p4_16_samples/action-synth.p4 --stf testdata/p4testgen/action-synth/action-synth_1.stf towers/k-p4.json
```

### Meta-execution of P4^P4ST

For comparison, `test-run-st`, `test-run-p4`, and `test-sim` run the P4-SpecTec scripts
and P4^P4ST directly on the SL interpreter of P4-SpecTec, without a tower.
`test-run-st` runs all script suites, `test-run-p4` runs all type-checking suites,
and `test-sim` runs all simulation suites.

```sh
# run the P4-SpecTec script tests
make test-run-st TEST_LOG=logs
# run the type-checking tests
make test-run-p4 TEST_LOG=logs
# run the STF packet tests
make test-sim TEST_LOG=logs
```

### Meta-meta-execution of P4ST^P4ST

The commands below run the P4-SpecTec scripts and P4^P4ST on P4ST^P4ST in `spec-meta`,
through the towers `towers/al-rel.json` and `towers/al-func.json` for the scripts,
`towers/al-p4-ok.json` for type checking, and `towers/al-p4.json` for simulation.
They take the options below:

- `SUITE=<NAME>` runs only the named test suite.
- `TIMEOUT=300` runs each test case with a timeout of 300 seconds.
- `TEST_LOG=logs` writes a per-test timing log into `logs/`.

`test-metacirc-run-al-st` runs the script suites.

```sh
# run all suites
make test-metacirc-run-al-st TEST_LOG=logs
# run each suite separately
make test-metacirc-run-al-st SUITE=spec-meta-rel-succ TEST_LOG=logs
make test-metacirc-run-al-st SUITE=spec-meta-rel-err TEST_LOG=logs
make test-metacirc-run-al-st SUITE=spec-meta-func-succ TEST_LOG=logs
```

`test-metacirc-run-al-p4` runs the type-checking suites.

```sh
# run all suites
make test-metacirc-run-al-p4 TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-run-al-p4 SUITE=run-positive TIMEOUT=300 TEST_LOG=logs
make test-metacirc-run-al-p4 SUITE=run-negative TIMEOUT=300 TEST_LOG=logs
```

`test-metacirc-sim-al` runs the simulation suites.

```sh
# run all suites
make test-metacirc-sim-al TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-sim-al SUITE=ebpf-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-al SUITE=ebpf-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-al SUITE=v1model-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-al SUITE=v1model-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-al SUITE=psa-p4c TIMEOUT=300 TEST_LOG=logs
```

### Meta-meta-execution of P4ST^Redex and P4ST^K

> [!WARNING]
> Running the entire test suites on P4ST^Redex and P4ST^K can take a very long time. `make test-metacirc-run-redex-p4` and `make test-metacirc-sim-k` took over 60 hours and 100 hours, respectively, on our machine. The `logs` folder contains the log file of each suite recorded in our runs.

The commands below run the P4-SpecTec scripts and P4^P4ST on P4ST^Redex and P4ST^K.
The scripts run on `spec-meta-redex-detcheck` and `spec-meta-k-detcheck`,
through the towers `towers/redex-detcheck*.json` and `towers/k-detcheck*.json`,
since the expected outputs of the scripts rely on determinism checking.
P4^P4ST runs on `spec-meta-redex`, through the towers `towers/redex-p4-ok.json` and `towers/redex-p4.json`,
and on `spec-meta-k`, through the towers `towers/k-p4-ok.json` and `towers/k-p4.json`.
They take the same options as the commands for P4ST^P4ST.

`test-metacirc-run-redex-st` runs the script suites.

```sh
# run all suites
make test-metacirc-run-redex-st TEST_LOG=logs
# run each suite separately
make test-metacirc-run-redex-st SUITE=spec-meta-rel-succ TEST_LOG=logs
make test-metacirc-run-redex-st SUITE=spec-meta-rel-err TEST_LOG=logs
make test-metacirc-run-redex-st SUITE=spec-meta-func-succ TEST_LOG=logs
```

`test-metacirc-run-redex-p4` runs the type-checking suites.

```sh
# run all suites
make test-metacirc-run-redex-p4 TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-run-redex-p4 SUITE=run-positive TIMEOUT=300 TEST_LOG=logs
make test-metacirc-run-redex-p4 SUITE=run-negative TIMEOUT=300 TEST_LOG=logs
```

`test-metacirc-sim-redex` runs the simulation suites.

```sh
# run all suites
make test-metacirc-sim-redex TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-sim-redex SUITE=ebpf-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-redex SUITE=ebpf-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-redex SUITE=v1model-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-redex SUITE=v1model-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-redex SUITE=psa-p4c TIMEOUT=300 TEST_LOG=logs
```

`test-metacirc-run-k-st` runs the script suites.

```sh
# run all suites
make test-metacirc-run-k-st TEST_LOG=logs
# run each suite separately
make test-metacirc-run-k-st SUITE=spec-meta-rel-succ TEST_LOG=logs
make test-metacirc-run-k-st SUITE=spec-meta-rel-err TEST_LOG=logs
make test-metacirc-run-k-st SUITE=spec-meta-func-succ TEST_LOG=logs
```

`test-metacirc-run-k-p4` runs the type-checking suites.

```sh
# run all suites
make test-metacirc-run-k-p4 TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-run-k-p4 SUITE=run-positive TIMEOUT=300 TEST_LOG=logs
make test-metacirc-run-k-p4 SUITE=run-negative TIMEOUT=300 TEST_LOG=logs
```

`test-metacirc-sim-k` runs the simulation suites.

```sh
# run all suites
make test-metacirc-sim-k TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-sim-k SUITE=ebpf-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-k SUITE=ebpf-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-k SUITE=v1model-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-k SUITE=v1model-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-k SUITE=psa-p4c TIMEOUT=300 TEST_LOG=logs
```

### Grouped P4 type checking and simulation

`test-metacirc-run-group-<base>` runs one of three groups of the `run-positive`
type-checking suite, so that the suite can be split over three commands.
`SUITE` and `GROUP` are required. Group `<n>` skips the programs listed in
`excludes/static/` and the other groups' folders under `excludes/metacirc-groups/run/`,
and compares the outcomes with `p4spectec/test-driver/expected/run-group/run-positive-<n>.expected`.
Groups 1, 2, and 3 have 927, 170, and 170 programs, respectively.

```sh
# run each group separately
make test-metacirc-run-group-redex SUITE=run-positive GROUP=1 TIMEOUT=300 TEST_LOG=logs
make test-metacirc-run-group-redex SUITE=run-positive GROUP=2 TIMEOUT=300 TEST_LOG=logs
make test-metacirc-run-group-redex SUITE=run-positive GROUP=3 TIMEOUT=300 TEST_LOG=logs
```

`test-metacirc-sim-group-<base>` runs one of four groups of the `v1model-p4testgen`
simulation suite, so that the suite can be split over four commands.
`SUITE` and `GROUP` are required. Group `<n>` skips the tests listed in
`excludes/static/`, `excludes/dynamic/`, and the other groups' folders under
`excludes/metacirc-groups/sim/`.
Since P4ST^Redex and P4ST^K take a long time, we recommend running the 1870 tests of
`v1model-p4testgen` on them group by group with these commands.

```sh
# run each group separately
make test-metacirc-sim-group-redex SUITE=v1model-p4testgen GROUP=1 TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-group-redex SUITE=v1model-p4testgen GROUP=2 TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-group-redex SUITE=v1model-p4testgen GROUP=3 TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-group-redex SUITE=v1model-p4testgen GROUP=4 TIMEOUT=300 TEST_LOG=logs
```

```sh
# run each group separately
make test-metacirc-sim-group-k SUITE=v1model-p4testgen GROUP=1 TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-group-k SUITE=v1model-p4testgen GROUP=2 TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-group-k SUITE=v1model-p4testgen GROUP=3 TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-group-k SUITE=v1model-p4testgen GROUP=4 TIMEOUT=300 TEST_LOG=logs
```

### P4ST^P4ST coverage

`metacirc cover-run` and `metacirc cover-sim` measure the SL instruction coverage of
P4ST^P4ST over many inputs.
The commands below run them on the test suites through the towers of P4ST^P4ST,
and write one report per run into `coverage/`; `COV_DIR=<DIR>` writes them into `<DIR>` instead.

- `metacirc-cover-run-st` runs the scripts of the script suites through `towers/al-rel.json`
  and `towers/al-func.json`, and writes `run-st-rel.cov` and `run-st-func.cov`.
- `metacirc-cover-run-p4` type-checks the programs of `run-positive` and `run-negative`
  through `towers/al-p4-ok.json`, and writes `run-p4.cov`.
- `metacirc-cover-sim` runs the STF tests of the simulation suites through `towers/al-p4.json`,
  one architecture at a time, and writes `sim-ebpf.cov`, `sim-v1model.cov`, and `sim-psa.cov`.
  `ARCH=<ARCH>` runs only one of `ebpf`, `v1model`, or `psa`.

```sh
# measure coverage of the script suites
make metacirc-cover-run-st
# measure coverage of the type-checking suites
make metacirc-cover-run-p4
# measure coverage of the simulation suites for all architectures
make metacirc-cover-sim
# measure coverage of the simulation suites for each architecture separately
make metacirc-cover-sim ARCH=ebpf
make metacirc-cover-sim ARCH=v1model
make metacirc-cover-sim ARCH=psa
```

Each command prints the outcomes of the inputs and the coverage of each run last, for example:

```
cover-run: programs 16 (pass 14, fail 2, crash 0), excluded 0; instruction coverage 1286/1998 (64.36%)
```

### Reproducing Tables 1, 2, and 3

`scripts/evaluation/table1` and `scripts/evaluation/table2` print Tables 1 and 2 of the paper
from the logs in the given directory,
and `scripts/evaluation/table3` prints Table 3 from the coverage reports in the given directory.

```sh
# print Table 1 and Table 2 from the logs in logs/
scripts/evaluation/table1 logs
scripts/evaluation/table2 logs
# print Table 3 from the coverage reports in coverage/
scripts/evaluation/table3 coverage
```

`logs/` already contains the logs of our runs.
To print the tables from your own runs, run the tests with `TEST_LOG=logs` as above.
A run writes `<name>-1.log` instead of `<name>.log` when it already exists,
so either remove our log first, or list the new log in `scripts/evaluation/suites.toml` as described below.

#### Selecting the logs of each suite

`scripts/evaluation/suites.toml` decides which logs make up each row and column of the tables.
`[columns]` names the columns: `meta` for P4^P4ST, shown only in Table 2,
and `al`, `redex`, and `k` for the towers.
Each `[[suites]]` entry is a row of the tables, in order:

```toml
[[suites]]
name = "NEG"                                  # row name
pass = ["fail"]                               # results counted as a pass
meta = ["run-sl#neg"]                         # sources of each column
al = ["metacirc-p4-al-run-negative"]
redex = ["metacirc-p4-redex-run-negative"]
k = ["metacirc-p4-k-run-negative"]
```

The comments at the top of `scripts/evaluation/suites.toml` describe the format of the sources.

#### Selecting the coverage reports of each row

`scripts/evaluation/coverage.toml` decides which coverage reports make up the rows of Table 3.
`static`, `dynamic`, and `custom` list the reports without `.cov`;
row `Both` takes the reports of `static` and `dynamic`, and row `+ Custom` takes those of `custom` in addition.

```toml
static = ["run-p4"]
dynamic = ["sim-ebpf", "sim-v1model", "sim-psa"]
custom = ["run-st-rel", "run-st-func"]
```
