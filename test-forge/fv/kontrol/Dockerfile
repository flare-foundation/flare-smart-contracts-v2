# ==============================================================================================
#  Reproducible Kontrol 1.0.248 toolchain for the Relay formal-verification proofs
#  (test-forge/fv/kontrol/*.t.sol). Everything is PINNED:
#    - base image      : nixos/nix  by sha256 digest
#    - nixpkgs (tools)  : NixOS/nixpkgs @ 9eac87a  (the commit our build actually used)
#    - Kontrol          : v1.0.248
#    - K                : v$(deps/k_release) == v7.1.334, fetched from RV's binary cache
#  so a teammate gets byte-for-byte the same toolchain the proofs were checked with.
#
#  Why a Dockerfile and not a Nix flake: Kontrol's own nix packaging is upstream-broken
#  (references solc_0_8_13, removed from nixpkgs), so we build from source and pin externally.
#
#  BUILD (recommended on a NATIVE x86_64 Linux host — fast, no emulation):
#      docker build -f test-forge/fv/kontrol/Dockerfile -t kontrol-local:ready .
#  On Apple Silicon: add `--platform linux/amd64` (slow, Rosetta). The kdist build is pinned to a
#  single core (taskset) so it is deadlock-safe under emulation; on native x86_64 you may delete the
#  `taskset -c 0` for a faster parallel build.
#
#  RUN A PROOF (per harness ~8-18 min build, then prove):
#      docker run --rm --platform linux/amd64 -v "$PWD/test-forge/fv/kontrol":/work \
#        kontrol-local:ready sh /work/run.sh
#  (run.sh installs a nix solc, writes foundry.toml, then forge build + kontrol build + kontrol prove.)
# ==============================================================================================

FROM --platform=linux/amd64 nixos/nix@sha256:bf1d938835ab96312f098fa6c2e9cab367728e0aad0646ee3e02a787c80d8fb8

# Pinned inputs (override at build time with --build-arg if ever needed)
ARG NIXPKGS=github:NixOS/nixpkgs/9eac87a12312b8f60dd52e1c6e1a265f6fc7f5fc
ARG KONTROL_REF=v1.0.248

# 1) nix config: emulation-safe flags + RV binary caches (pinned signing keys)
RUN printf '%s\n' \
      'experimental-features = nix-command flakes' \
      'accept-flake-config = true' \
      'max-jobs = auto' \
      'filter-syscalls = false' \
      'sandbox = false' \
      'substituters = https://cache.nixos.org https://k-framework-binary.cachix.org https://k-framework.cachix.org' \
      'trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= k-framework-binary.cachix.org-1:pJedQ8iG19BW3v/DMMmiRVtwRBGO3fyMv2Ws0OpBADs= k-framework.cachix.org-1:jeyMXB2h28gpNRjuVkehg+zLj62ma1RnyyopA/20yFE=' \
      >> /etc/nix/nix.conf

# 2) Base tooling + JDK17 + Python3.11 + Foundry + solc + the C/C++ plugin toolchain (pinned nixpkgs).
#    Installed one at a time so a file collision on one package does not abort the batch.
#    clang only (NOT gcc) to avoid the cc/c++ collision; `which` omitted (the base image provides it).
RUN for p in git uv python311 jdk17 cachix foundry solc \
             gnumake cmake pkg-config clang binutils flex bison perl \
             gnused gawk gnugrep findutils diffutils coreutils util-linux \
             openssl openssl.dev gmp gmp.dev mpfr mpfr.dev boost boost.dev \
             secp256k1 cryptopp procps autoconf automake libtool; do \
      nix profile install --priority 4 "${NIXPKGS}#${p}" || echo "skip/collision ${p}"; \
    done
ENV PATH=/root/.nix-profile/bin:/root/.local/bin:$PATH
ENV CPATH=/root/.nix-profile/include
ENV C_INCLUDE_PATH=/root/.nix-profile/include
ENV CPLUS_INCLUDE_PATH=/root/.nix-profile/include
ENV LIBRARY_PATH=/root/.nix-profile/lib
ENV LD_LIBRARY_PATH=/root/.nix-profile/lib
ENV PKG_CONFIG_PATH=/root/.nix-profile/lib/pkgconfig
ENV CMAKE_PREFIX_PATH=/root/.nix-profile
ENV CMAKE_POLICY_VERSION_MINIMUM=3.5

# 3) Install K (kore/llvm-backend fetched prebuilt from the RV cache) — bypasses the broken kontrol nix pkg
RUN nix profile install github:runtimeverification/kup --accept-flake-config
RUN git clone --depth 1 --branch "${KONTROL_REF}" https://github.com/runtimeverification/kontrol /kontrol
WORKDIR /kontrol
RUN kup install k.openssl.secp256k1 --version "v$(cat deps/k_release)"

# 4) Python deps via the nix Python (never uv's own standalone download, which can't exec on NixOS),
#    then patch pyk's kdist to a fork-based pool (the default 'spawn' pool deadlocks under Rosetta).
RUN UV_PYTHON_DOWNLOADS=never uv sync --python "$(command -v python3.11)"
RUN sed -i "s/get_context('spawn')/get_context('fork')/g" \
      /kontrol/.venv/lib/python3.11/site-packages/pyk/kdist/_kdist.py

# 5) Build the KEVM/Kontrol kdist (pinned by deps/k_release + uv.lock). taskset -c 0 forces a single
#    core so the LLVM-backend parallel compile cannot deadlock under Rosetta; ulimit raises the Nix
#    evaluator stack. On native x86_64 you may drop `taskset -c 0` to build in parallel.
RUN export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"; \
    ulimit -s 1048576 || true; \
    taskset -c 0 uv run kdist --verbose build "kontrol.*"
RUN uv run kontrol version

# kontrol on PATH for `docker run ... kontrol prove`
ENV PATH=/kontrol/.venv/bin:$PATH
WORKDIR /work
