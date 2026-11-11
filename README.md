# Meta-Meta Artifact

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
├── p4spectec/          # Rust implementation of meta-meta execution, built on top of P4-SpecTec
│   ├── src/            # P4-SpecTec, with metacircular towers in src/metacirc/
│   └── test-driver/    # Test drivers, with test suite registrations (suites/) and expected results (expected/)
├── spec/               # P4^P4ST: the P4 specification from P4-SpecTec
├── spec-meta/          # P4ST^P4ST: the P4-SpecTec AL specification in P4-SpecTec
├── spec-meta-redex/    # P4ST^Redex: the P4-SpecTec AL specification in PLT Redex
├── spec-meta-k/        # P4ST^K: the P4-SpecTec AL specification in K
├── towers/             # Tower configurations running P4^P4ST on P4ST^P4ST, P4ST^Redex, or P4ST^K
├── p4c/                # P4 include files (p4include/) and test programs (testdata/) from p4c
├── testdata/           # STF tests from P4-SpecTec
├── excludes/           # Excluded tests from P4-SpecTec
├── patches/            # Patched STF tests from P4-SpecTec
├── docs/               # P4 specification documents from P4-SpecTec
├── scripts/            # Scripts printing statistics of spec-meta-redex and spec-meta-k
└── logs/               # Logs recorded by our runs; TEST_LOG=logs also writes here
```

## 3. Evaluation

Run every command from `/meta` in the container, or from the repository root for option 3.

### Test suites

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
| `v1model-p4c` | v1model | `p4c/testdata/p4_16_samples/` |
| `v1model-p4testgen` | v1model | `testdata/p4testgen/` |
| `ebpf-p4c` | ebpf | `p4c/testdata/p4_16_samples/` |
| `ebpf-p4testgen` | ebpf | `testdata/p4testgen/` |
| `psa-p4c` | psa | `p4c/testdata/p4_16_samples/` |

### Meta-execution of P4^P4ST

For comparison, `test-run-sl` and `test-sim-sl` run P4^P4ST directly on the SL interpreter
of P4-SpecTec, without a tower.
`test-run-sl` runs all type-checking suites, and `test-sim-sl` runs all simulation suites.

```sh
# run the type-checking tests
make test-run-sl TEST_LOG=logs
# run the STF packet tests
make test-sim-sl TEST_LOG=logs
```

### Meta-meta-execution of P4ST^P4ST

The commands below run P4^P4ST on P4ST^P4ST in `spec-meta`, through the tower
`towers/al-p4-ok.json` for type checking and `towers/al-p4.json` for simulation.
They take the options below:

- `SUITE=<NAME>` runs only the named test suite.
- `TIMEOUT=300` runs each test case with a timeout of 300 seconds.
- `TEST_LOG=logs` writes a per-test timing log into `logs/`.

`test-metacirc-run-al` runs the type-checking suites.

```sh
# run all suites
make test-metacirc-run-al TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-run-al SUITE=run-positive TIMEOUT=300 TEST_LOG=logs
make test-metacirc-run-al SUITE=run-negative TIMEOUT=300 TEST_LOG=logs
```

`test-metacirc-sim-al` runs the simulation suites.

```sh
# run all suites
make test-metacirc-sim-al TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-sim-al SUITE=v1model-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-al SUITE=v1model-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-al SUITE=ebpf-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-al SUITE=ebpf-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-al SUITE=psa-p4c TIMEOUT=300 TEST_LOG=logs
```

### Meta-meta-execution of P4ST^Redex and P4ST^K

The commands below run P4^P4ST on P4ST^Redex in `spec-meta-redex`, through the towers
`towers/redex-p4-ok.json` and `towers/redex-p4.json`, and on P4ST^K in `spec-meta-k`,
through the towers `towers/k-p4-ok.json` and `towers/k-p4.json`.
They take the same options as the commands for P4ST^P4ST.

`test-metacirc-run-redex` runs the type-checking suites.

```sh
# run all suites
make test-metacirc-run-redex TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-run-redex SUITE=run-positive TIMEOUT=300 TEST_LOG=logs
make test-metacirc-run-redex SUITE=run-negative TIMEOUT=300 TEST_LOG=logs
```

`test-metacirc-sim-redex` runs the simulation suites.

```sh
# run all suites
make test-metacirc-sim-redex TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-sim-redex SUITE=v1model-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-redex SUITE=v1model-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-redex SUITE=ebpf-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-redex SUITE=ebpf-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-redex SUITE=psa-p4c TIMEOUT=300 TEST_LOG=logs
```

`test-metacirc-run-k` runs the type-checking suites.

```sh
# run all suites
make test-metacirc-run-k TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-run-k SUITE=run-positive TIMEOUT=300 TEST_LOG=logs
make test-metacirc-run-k SUITE=run-negative TIMEOUT=300 TEST_LOG=logs
```

`test-metacirc-sim-k` runs the simulation suites.

```sh
# run all suites
make test-metacirc-sim-k TIMEOUT=300 TEST_LOG=logs
# run each suite separately
make test-metacirc-sim-k SUITE=v1model-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-k SUITE=v1model-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-k SUITE=ebpf-p4c TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-k SUITE=ebpf-p4testgen TIMEOUT=300 TEST_LOG=logs
make test-metacirc-sim-k SUITE=psa-p4c TIMEOUT=300 TEST_LOG=logs
```

> [!WARNING]
> Running the entire test suites on P4ST^Redex and P4ST^K can take a very long time. `make test-metacirc-run-redex` and `make test-metacirc-sim-k` took over 60 hours and 100 hours, respectively, on our machine. The `logs` folder contains the log file of each suite recorded in our runs.

### Grouped P4 simulation

`test-metacirc-sim-group-<base>` runs one of four groups of the `v1model-p4testgen`
simulation suite, so that the suite can be split over four commands.
`SUITE` and `GROUP` are required. Group `<n>` skips the tests listed in
`excludes/static/`, `excludes/dynamic/`, and the other groups' folders under
`excludes/metacirc-groups/`.
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

### Running a single P4 program

The `metacirc` binary runs a single P4 program or STF test through a tower.
For option 3, either add the `bin` folder of the repository root to `PATH`,
or run it as `./bin/metacirc` instead of `metacirc`.

Run `metacirc run-meta --help` or `metacirc sim --help` for the full list of options.

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

- `<ARCH>`: the architecture of the P4 program, one of `v1model`, `ebpf`, or `psa`.
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
