# ---- Racket installers at the repository root, if exist ----
ARG RACKET_VERSION=9.3
FROM scratch AS racket-installer
ARG RACKET_VERSION
COPY racket-${RACKET_VERSION}-*-linux-buster-cs.s[h] /

# ---- Image ----
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETARCH

# ---- System packages and document dependencies ----
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl build-essential pkg-config python3 ruby-dev \
 && rm -rf /var/lib/apt/lists/* \
 && gem install asciidoctor asciidoctor-pdf rouge --no-document

# ---- Racket ----
ARG RACKET_VERSION
ARG RACKET_SHA256_AMD64=30dc59d9b5af083eacf793253d35782c5231e8bfb7a7331fe32ccd9a41fd792f
ARG RACKET_SHA256_ARM64=26e4d1c3bf8954c4413fb6737af5d211d44c1e158e34e4c90e0af1cde6353c9a
RUN --mount=type=bind,from=racket-installer,target=/racket-installer \
    case "${TARGETARCH}" in \
      amd64) arch=x86_64;  sha256="${RACKET_SHA256_AMD64}" ;; \
      arm64) arch=aarch64; sha256="${RACKET_SHA256_ARM64}" ;; \
      *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && installer="racket-${RACKET_VERSION}-${arch}-linux-buster-cs.sh" \
 && if [ -f "/racket-installer/${installer}" ]; then \
      script="/racket-installer/${installer}"; \
    else \
      script=/tmp/racket.sh \
      && curl -fSL --retry 5 --connect-timeout 30 -o "${script}" \
           "https://download.racket-lang.org/releases/${RACKET_VERSION}/installers/${installer}"; \
    fi \
 && echo "${sha256}  ${script}" | sha256sum -c - \
 && sh "${script}" --in-place --dest /opt/racket < /dev/null \
 && rm -f /tmp/racket.sh
ENV PATH="/opt/racket/bin:${PATH}"

# ---- K framework (amd64 only) ----
ARG K_VERSION=7.1.337
ARG K_SHA256=3692997e6bfa4be490d24bd9201289d4a05872889c9da725dda21e99d03d6990
RUN if [ "${TARGETARCH}" = amd64 ]; then \
      curl -fsSL --retry 5 --connect-timeout 30 -o /tmp/kframework.deb \
        "https://github.com/runtimeverification/k/releases/download/v${K_VERSION}/kframework_${K_VERSION}_amd64_ubuntu_noble.deb" \
      && echo "${K_SHA256}  /tmp/kframework.deb" | sha256sum -c - \
      && apt-get update \
      && apt-get install -y --no-install-recommends /tmp/kframework.deb z3 \
      && rm -rf /var/lib/apt/lists/* /tmp/kframework.deb; \
    fi

# ---- P4-SpecTec ----
ENV RUSTUP_HOME=/usr/local/rustup CARGO_HOME=/usr/local/cargo
ENV PATH="/usr/local/cargo/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --profile minimal --default-toolchain none

WORKDIR /meta

COPY p4spectec/rust-toolchain.toml p4spectec/
RUN cd p4spectec && rustup toolchain install && rustup default "$(rustup show active-toolchain | cut -d' ' -f1)"

# ---- Build ----
COPY --exclude=racket-*.sh . .

RUN find . -exec touch -h -d "@$(date +%s)" {} + \
 && make build redex \
 && if [ "${TARGETARCH}" = amd64 ]; then make kompile; fi \
 && cd p4spectec \
 && cargo build --locked --release --manifest-path test-driver/Cargo.toml --target-dir target --bins

ENV PATH="/meta/bin:${PATH}"
CMD ["bash"]
