# Rust builds and independent acceptance executables

CARGO := cargo
TARGET_DIR := $(if $(CARGO_TARGET_DIR),$(CARGO_TARGET_DIR),target)
ifeq ($(filter /%,$(TARGET_DIR)),)
TARGET_DIR := $(CURDIR)/$(TARGET_DIR)
endif

.PHONY: build release debug stat fmt fmt-check lint rustdoc clean

debug:
	$(CARGO) build --locked --bin p4spectec --target-dir "$(TARGET_DIR)"

build release:
	$(CARGO) build --locked --release --bin p4spectec --target-dir "$(TARGET_DIR)"

stat:
	$(CARGO) build --locked --release --bin stat --target-dir "$(TARGET_DIR)"

fmt:
	$(CARGO) fmt
	$(CARGO) fmt --manifest-path test-driver/Cargo.toml

fmt-check:
	$(CARGO) fmt --check
	$(CARGO) fmt --manifest-path test-driver/Cargo.toml --check

lint:
	$(CARGO) clippy --locked --all-targets --no-deps --target-dir "$(TARGET_DIR)"
	$(CARGO) clippy --locked --all-targets --no-deps --manifest-path test-driver/Cargo.toml --target-dir "$(TARGET_DIR)"

rustdoc:
	RUSTDOCFLAGS="-D warnings" $(CARGO) doc --locked --no-deps --target-dir "$(TARGET_DIR)"

clean:
	$(CARGO) clean --target-dir "$(TARGET_DIR)"

.DEFAULT_GOAL := test

.PHONY: test

test: test-expected test-sim

# Standalone acceptance driver; registrations live in test-driver/suites/
# TEST_LOG=DIR writes per-test timing logs of p4parse, run, sim, and micro
# TIMEOUT=SECONDS records a run or sim test still running after it as a timeout
.PHONY: test-expected test-p4parse test-run-p4 test-run-st
DRIVER = $(CARGO) run --locked --release --manifest-path test-driver/Cargo.toml --target-dir "$(TARGET_DIR)" -- $(if $(TEST_LOG),--log "$(abspath $(TEST_LOG))")
CORPUS_ARGS = $(if $(TIMEOUT),--timeout $(TIMEOUT))

test-p4parse:
	$(DRIVER) p4parse

test-run-p4:
	$(DRIVER) run sl $(CORPUS_ARGS)

# Standalone spec-language sources checked by pipeline stage
test-run-st:
	$(DRIVER) micro sl

test-expected: test-p4parse test-run-p4 test-run-st

# Native simulation uses source-derived expectations in both cached modes
.PHONY: test-sim

test-sim:
	$(DRIVER) sim sl $(CORPUS_ARGS)
