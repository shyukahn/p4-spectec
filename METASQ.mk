# Independent metacircular build and P4 execution corpus
# TEST_LOG=DIR writes per-test timing logs of the metacirc run and sim targets
# TIMEOUT=SECONDS records a source of those targets still running after it as a timeout
# SUITE=NAME runs only that registered suite in those targets
# SUITE=NAME and GROUP=NAME select the registered suite and group of the run-group and sim-group
# targets, which require both
# COV_DIR=DIR is where the coverage targets write their reports (default coverage)
# ARCH=NAME runs metacirc-cover-sim on that architecture only

CARGO := cargo
RUST_DIR = p4spectec
METACIRC = bin/metacirc
override CARGO_TARGET_DIR := $(if $(CARGO_TARGET_DIR),$(CARGO_TARGET_DIR),$(RUST_DIR)/target)
ifeq ($(filter /%,$(CARGO_TARGET_DIR)),)
override CARGO_TARGET_DIR := $(CURDIR)/$(CARGO_TARGET_DIR)
endif
export CARGO_TARGET_DIR

.DEFAULT_GOAL := metacirc
METACIRC_TEST = $(CARGO) run --locked --release --manifest-path test-driver/Cargo.toml --target-dir "$(CARGO_TARGET_DIR)" --bin metacirc-test -- $(if $(TEST_LOG),--log "$(abspath $(TEST_LOG))")
CORPUS_ARGS = $(if $(TIMEOUT),--timeout $(TIMEOUT)) $(if $(SUITE),--suite $(SUITE))


.PHONY: metacirc metacirc-cli kompile redex test-metacirc-run-al-p4 test-metacirc-run-k-p4 test-metacirc-run-redex-p4 test-metacirc-run-al-st test-metacirc-run-k-st test-metacirc-run-redex-st test-metacirc-run-group-al test-metacirc-run-group-k test-metacirc-run-group-redex test-metacirc-sim-al test-metacirc-sim-k test-metacirc-sim-redex test-metacirc-sim-group-al test-metacirc-sim-group-k test-metacirc-sim-group-redex metacirc-cover-run-p4 metacirc-cover-run-st metacirc-cover-sim clean

metacirc-cli:
	cd $(RUST_DIR) && $(CARGO) build --locked --release --bin metacirc --target-dir "$(CARGO_TARGET_DIR)"

metacirc: metacirc-cli
	mkdir -p $(dir $(METACIRC))
	rm -f ./$(METACIRC)
	cp "$(CARGO_TARGET_DIR)/release/metacirc" ./$(METACIRC)

# The libraries k towers load (`kompiled` in towers/k*.json), compiled from spec-meta-k
# and its determinism-checking copy spec-meta-k-detcheck, with the metacirc binary that loads them
KSPECDIR = spec-meta-k
KLIBRARY = $(KSPECDIR)/kompiled/libspec-meta-k.so
KSPECDIR_DETCHECK = spec-meta-k-detcheck
KLIBRARY_DETCHECK = $(KSPECDIR_DETCHECK)/kompiled/libspec-meta-k.so

kompile: metacirc $(KLIBRARY) $(KLIBRARY_DETCHECK)

$(KLIBRARY): $(wildcard $(KSPECDIR)/*/*.k)
	kompile $(KSPECDIR)/3-execution/3.14-entry.k --main-module AL --syntax-module SYNTAX \
	  -o $(dir $(KLIBRARY)) --llvm-kompile-type c --llvm-kompile-output $(notdir $(KLIBRARY)) -O2

$(KLIBRARY_DETCHECK): $(wildcard $(KSPECDIR_DETCHECK)/*/*.k)
	kompile $(KSPECDIR_DETCHECK)/3-execution/3.14-entry.k --main-module AL --syntax-module SYNTAX \
	  -o $(dir $(KLIBRARY_DETCHECK)) --llvm-kompile-type c --llvm-kompile-output $(notdir $(KLIBRARY_DETCHECK)) -O2

# The entry modules redex towers run (`module` in towers/redex*.json), compiled from
# spec-meta-redex and its determinism-checking copy spec-meta-redex-detcheck,
# with the metacirc binary that runs them; raco make recompiles only what changed
REDEXSPECDIR = spec-meta-redex
REDEXMODULE = $(REDEXSPECDIR)/3-execution/3.15-entry.rkt
REDEXSPECDIR_DETCHECK = spec-meta-redex-detcheck
REDEXMODULE_DETCHECK = $(REDEXSPECDIR_DETCHECK)/3-execution/3.15-entry.rkt

redex: metacirc
	raco make -v $(REDEXMODULE) $(REDEXMODULE_DETCHECK)

# P4 corpus through the AL/P4 towers
test-metacirc-run-al-p4:
	cd $(RUST_DIR) && $(METACIRC_TEST) run al --input p4 $(CORPUS_ARGS)

# P4 corpus through the K/P4 towers, spec-meta-k on its K library (ST-in-K)
test-metacirc-run-k-p4:
	cd $(RUST_DIR) && $(METACIRC_TEST) run k --input p4 $(CORPUS_ARGS)

# P4 corpus through the Redex/P4 towers, spec-meta-redex in racket (ST-in-Redex)
test-metacirc-run-redex-p4:
	cd $(RUST_DIR) && $(METACIRC_TEST) run redex --input p4 $(CORPUS_ARGS)

# Spec-language script suites through the AL tower
test-metacirc-run-al-st:
	cd $(RUST_DIR) && $(METACIRC_TEST) run al --input al $(CORPUS_ARGS)

# Spec-language script suites through the K tower on spec-meta-k-detcheck (ST-in-K)
test-metacirc-run-k-st:
	cd $(RUST_DIR) && $(METACIRC_TEST) run k --input al $(CORPUS_ARGS)

# Spec-language script suites through the Redex tower on spec-meta-redex-detcheck (ST-in-Redex)
test-metacirc-run-redex-st:
	cd $(RUST_DIR) && $(METACIRC_TEST) run redex --input al $(CORPUS_ARGS)

# One group of a P4 corpus suite of suites/metacirc/run-group.toml through the AL/P4,
# K/P4, or Redex/P4 tower, against the group's expected file for the suite
GROUP_ARGS = --suite $(SUITE) --group $(GROUP) $(if $(TIMEOUT),--timeout $(TIMEOUT))
RUN_GROUP_TARGETS := test-metacirc-run-group-al test-metacirc-run-group-k test-metacirc-run-group-redex

$(RUN_GROUP_TARGETS):
	$(if $(and $(SUITE),$(GROUP)),,$(error SUITE and GROUP are required, e.g. make $@ SUITE=run-positive GROUP=1))
	cd $(RUST_DIR) && $(METACIRC_TEST) run-group $(@:test-metacirc-run-group-%=%) $(GROUP_ARGS)

# Registered simulation suites through the AL/P4 tower, against native expectations
test-metacirc-sim-al:
	cd $(RUST_DIR) && $(METACIRC_TEST) sim al $(CORPUS_ARGS)

# Registered simulation suites through the K/P4 tower (ST-in-K), against native expectations
test-metacirc-sim-k:
	cd $(RUST_DIR) && $(METACIRC_TEST) sim k $(CORPUS_ARGS)

# Registered simulation suites through the Redex/P4 tower (ST-in-Redex), against native expectations
test-metacirc-sim-redex:
	cd $(RUST_DIR) && $(METACIRC_TEST) sim redex $(CORPUS_ARGS)

# One group of a simulation suite of suites/metacirc/sim-group.toml through the AL/P4,
# K/P4, or Redex/P4 tower, against the group's expected file for the suite
SIM_GROUP_ARGS = --suite $(SUITE) --group $(GROUP) $(if $(TIMEOUT),--timeout $(TIMEOUT))
SIM_GROUP_TARGETS := test-metacirc-sim-group-al test-metacirc-sim-group-k test-metacirc-sim-group-redex

$(SIM_GROUP_TARGETS):
	$(if $(and $(SUITE),$(GROUP)),,$(error SUITE and GROUP are required, e.g. make $@ SUITE=v1model-p4c GROUP=1))
	cd $(RUST_DIR) && $(METACIRC_TEST) sim-group $(@:test-metacirc-sim-group-%=%) $(GROUP_ARGS)

# SL instruction coverage of spec-meta, the base of the AL towers, written to $(COV_DIR)/*.cov
COV_DIR = coverage
COVER_SIM_ARCHS := v1model ebpf psa
COVER_SIM_ARCH = $(if $(ARCH),$(ARCH),$(COVER_SIM_ARCHS))
COVER_SIM_STF_v1model = p4c/testdata/p4_16_samples testdata/p4testgen
COVER_SIM_STF_ebpf = p4c/testdata/p4_16_samples testdata/p4testgen
COVER_SIM_STF_psa = p4c/testdata/p4_16_samples
COVER_SIM_PATCH_v1model = patches/v1model

# The P4 programs of the type-checking suites through the AL/P4 tower
metacirc-cover-run-p4: metacirc
	mkdir -p $(COV_DIR)
	./$(METACIRC) cover-run towers/al-p4-ok.json -i p4c/p4include -e excludes/static \
	  -p p4c/testdata/p4_16_samples -p p4c/testdata/p4_16_errors --cov $(COV_DIR)/run-p4.cov

# The scripts of the script suites through the AL tower, entering at Main and at $$main
metacirc-cover-run-st: metacirc
	mkdir -p $(COV_DIR)
	./$(METACIRC) cover-run towers/al-rel.json -p testdata/spec-meta/rel --cov $(COV_DIR)/run-st-rel.cov
	./$(METACIRC) cover-run towers/al-func.json -p testdata/spec-meta/func --cov $(COV_DIR)/run-st-func.cov

# The STF tests of the simulation suites through the AL/P4 tower, one report per architecture
metacirc-cover-sim: metacirc
	$(if $(filter-out $(COVER_SIM_ARCHS),$(COVER_SIM_ARCH)),$(error ARCH must be one of $(COVER_SIM_ARCHS)))
	mkdir -p $(COV_DIR)
	$(foreach arch,$(COVER_SIM_ARCH),./$(METACIRC) cover-sim towers/al-p4.json --arch $(arch) \
	  -i p4c/p4include -e excludes/static -e excludes/dynamic --p4 p4c/testdata/p4_16_samples \
	  $(addprefix --stf ,$(COVER_SIM_STF_$(arch))) $(addprefix --patch ,$(COVER_SIM_PATCH_$(arch))) \
	  --cov $(COV_DIR)/sim-$(arch).cov && ) true

clean:
	rm -f ./$(METACIRC)
	rm -rf ./$(dir $(KLIBRARY)) ./$(dir $(KLIBRARY_DETCHECK))
	find $(REDEXSPECDIR) $(REDEXSPECDIR_DETCHECK) -name compiled -type d -prune -exec rm -rf {} +
