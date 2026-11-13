SPEC = bin/p4spectec
STAT = bin/stat
FALLTHROUGH = bin/fallthrough
RUST_DIR = p4spectec
# Resolve an override before entering the Rust crate or documentation directories
override CARGO_TARGET_DIR := $(if $(CARGO_TARGET_DIR),$(CARGO_TARGET_DIR),$(RUST_DIR)/target)
ifeq ($(filter /%,$(CARGO_TARGET_DIR)),)
override CARGO_TARGET_DIR := $(CURDIR)/$(CARGO_TARGET_DIR)
endif
export CARGO_TARGET_DIR

.DEFAULT_GOAL := build
# Root workflows share the installed executable and generated document sections
# Recursive Rust tests still use the caller's parallel job count
.NOTPARALLEL:

.PHONY: build release debug stat fallthrough fmt fmt-check lint rustdoc clean

build release debug:
	$(MAKE) -C $(RUST_DIR) CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" $@
	mkdir -p $(dir $(SPEC))
	rm -f ./$(SPEC)
	cp "$(CARGO_TARGET_DIR)/$(if $(filter debug,$@),debug,release)/p4spectec" ./$(SPEC)

stat:
	$(MAKE) -C $(RUST_DIR) CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" $@
	mkdir -p $(dir $(STAT))
	rm -f ./$(STAT)
	cp "$(CARGO_TARGET_DIR)/release/stat" ./$(STAT)

fallthrough:
	$(MAKE) -C $(RUST_DIR) CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" $@
	mkdir -p $(dir $(FALLTHROUGH))
	rm -f ./$(FALLTHROUGH)
	cp "$(CARGO_TARGET_DIR)/release/fallthrough" ./$(FALLTHROUGH)

fmt fmt-check lint rustdoc:
	$(MAKE) -C $(RUST_DIR) CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" $@

# End-to-end acceptance
TEST_TARGETS := test test-expected test-p4parse test-run-p4 test-run-st test-sim

.PHONY: $(TEST_TARGETS)
# Resolve TEST_LOG here; the recursive make runs inside the Rust crate
$(TEST_TARGETS):
	$(MAKE) -C $(RUST_DIR) CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" $(if $(TEST_LOG),TEST_LOG="$(abspath $(TEST_LOG))") $@

METAMETA_TARGETS := metameta kompile redex test-mm-run-st-p4 \
  test-mm-run-k-p4 test-mm-run-redex-p4 \
  test-mm-run-st-st test-mm-run-k-st test-mm-run-redex-st \
  test-mm-run-group-st \
  test-mm-run-group-k test-mm-run-group-redex \
  test-mm-sim-st \
  test-mm-sim-k test-mm-sim-redex test-mm-sim-group-st \
  test-mm-sim-group-k test-mm-sim-group-redex \
  mm-cover-run-p4 mm-cover-run-st mm-cover-sim

.PHONY: $(METAMETA_TARGETS)
$(METAMETA_TARGETS):
	$(MAKE) -f METAMETA.mk CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" $(if $(TEST_LOG),TEST_LOG="$(abspath $(TEST_LOG))") $@

# Specification documents
.PHONY: p4spec-draft p4spec-draft-html p4spec-release p4spec-release-html

p4spec-draft:
	$(MAKE) -C docs/p4 CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" draft
p4spec-draft-html:
	$(MAKE) -C docs/p4 CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" draft-html
p4spec-release:
	$(MAKE) -C docs/p4 CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" release
p4spec-release-html:
	$(MAKE) -C docs/p4 CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" release-html

clean:
	rm -f ./$(SPEC) ./$(STAT)
	$(MAKE) -f METAMETA.mk clean
	$(MAKE) -C $(RUST_DIR) CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" clean
