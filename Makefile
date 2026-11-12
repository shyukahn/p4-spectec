SPEC = bin/p4spectec
STAT = bin/stat
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

.PHONY: build release debug stat fmt fmt-check lint rustdoc clean promote

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

fmt fmt-check lint rustdoc:
	$(MAKE) -C $(RUST_DIR) CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" $@

# End-to-end acceptance and explicit snapshot updates
TEST_TARGETS := test test-expected test-elab test-algo test-structure test-prose \
  test-adoc test-p4parse test-run-p4 test-sim test-promote

.PHONY: $(TEST_TARGETS)
# Resolve TEST_LOG here; the recursive make runs inside the Rust crate
$(TEST_TARGETS):
	$(MAKE) -C $(RUST_DIR) CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" $(if $(TEST_LOG),TEST_LOG="$(abspath $(TEST_LOG))") $@

METACIRC_TARGETS := metacirc kompile redex test-metacirc-run-al-p4 \
  test-metacirc-run-k-p4 test-metacirc-run-redex-p4 \
  test-metacirc-run-group-al \
  test-metacirc-run-group-k test-metacirc-run-group-redex \
  test-metacirc-sim-al \
  test-metacirc-sim-k test-metacirc-sim-redex test-metacirc-sim-group-al \
  test-metacirc-sim-group-k test-metacirc-sim-group-redex

.PHONY: $(METACIRC_TARGETS)
$(METACIRC_TARGETS):
	$(MAKE) -f METASQ.mk CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" $(if $(TEST_LOG),TEST_LOG="$(abspath $(TEST_LOG))") $@

promote: test-promote

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
	$(MAKE) -f METASQ.mk clean
	$(MAKE) -C $(RUST_DIR) CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" clean
