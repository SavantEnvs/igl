# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile (SMALL form, PREFERRED) — builds ON TOP of the org C/C++ base
# image (ghcr.io/savantenvs/base). The base already provides debian + clang/llvm +
# libFuzzer/afl++ + the identities + the build-contract ENV, so this only adds the
# per-commit build (built on top of the prebuilt base, rather than building the toolchain in-image).
#
# Build (from the repo root):
#   DOCKER_BUILDKIT=1 docker build -f mayhem/Dockerfile \
#       --build-arg COMMIT=$(git rev-parse HEAD) \
#       [--build-arg SOURCE_DATE_EPOCH=$(date +%s)] \
#       -t mytag .

# The org base, pinned to a fixed DATE-tagged base (YYYYMMDD; shared by all integrations
# minted against it). Use the current dated tag; pin by digest in production: ...base@sha256:<digest>.
FROM ghcr.io/savantenvs/base:20261023

ARG COMMIT
ARG REPO_URL
# SOURCE_DATE_EPOCH stays an ARG (available to build.sh); do NOT bake it as an ENV — an
# empty value breaks clang ("must be a non-negative decimal integer") both here and for
# any in-image rebuild. build.sh unsets it when empty.
ARG SOURCE_DATE_EPOCH

# Sanitizer override: the base exports SANITIZER_FLAGS (ASan+UBSan, halting) as the default.
# To change it for a build (e.g. ASan-only, or add MSan): --build-arg SANITIZER_FLAGS="...".
# Declare it WITHOUT a default (no '='): an undefaulted ARG lets the base ENV flow through to
# build.sh when not passed, and an explicit --build-arg overrides it. (An empty default — `=` —
# would instead shadow the base ENV and silently wipe the sanitizers.)
ARG SANITIZER_FLAGS
# Coverage (optional, off by default): instrument the TEST build to measure how much of the project
# the suite exercises — --build-arg COVERAGE_FLAGS="-fprofile-instr-generate -fcoverage-mapping".
# Empty by default (no effect on the normal oracle build); build.sh appends it to the test build only.
ARG COVERAGE_FLAGS=
# Build parallelism (optional). build.sh falls back to nproc when unset: --build-arg MAYHEM_JOBS=8
ARG MAYHEM_JOBS=

# If mayhem/build.sh needs EXTRA apt packages, install them as root before the build
# (re-pin to SOURCE_DATE_EPOCH first for reproducibility — repro-sources-list.sh ships
# in the base):
#   USER root
#   RUN [ -n "$SOURCE_DATE_EPOCH" ] && repro-sources-list.sh || true ; \
#       apt-get update && apt-get install -yq --no-install-recommends <pkgs> \
#    && rm -rf /var/lib/apt/lists/*
#   USER mayhem

# Anything the upstream build would download, or a library apt lacks or ships at the wrong version, is
# built once from pinned source into a static prefix under /opt/toolchains/deps/<name>-<version>/
# (root-owned, world-readable, no .so); build.sh just points at it, e.g. via PKG_CONFIG_PATH
# (SPEC §6.2 item 19). The source stays in $d/src and the build runs out of tree with -gdwarf-3, so
# backtraces show /opt/toolchains/deps/... paths and the harness binary stays DWARF <= 3. Example:
#   USER root
#   ARG JANSSON_VER=2.14.1
#   ARG JANSSON_SHA256=<sha256 of the tarball>
#   RUN d=/opt/toolchains/deps/jansson-${JANSSON_VER} && mkdir -p "$d/src" /tmp/dep-build \
#    && curl -fsSL -o /tmp/dep.tgz \
#         https://github.com/akheron/jansson/releases/download/v${JANSSON_VER}/jansson-${JANSSON_VER}.tar.gz \
#    && echo "${JANSSON_SHA256}  /tmp/dep.tgz" | sha256sum -c - \
#    && tar -xzf /tmp/dep.tgz --strip-components=1 -C "$d/src" && cd /tmp/dep-build \
#    && "$d/src/configure" --prefix="$d" --disable-shared --enable-static CFLAGS="-O2 -g -gdwarf-3" \
#    && make -j"$(nproc)" install \
#    && cd / && rm -rf /tmp/dep-build /tmp/dep.tgz && chmod -R a+rX "$d"
#   USER mayhem

# IGL's own build (deploy_deps.py / third-party/bootstrap.py) clones its dependencies at configure time.
# The ones the device-free parsers need are fetched here instead, each pinned to the exact revision in
# third-party/bootstrap-deps.json, into /opt/toolchains/deps/<name>-<rev>/src (SPEC §6.2 item 19).
# libktx (KTX1/KTX2 reader + basisu transcoder) is built once here, out of tree, static and uninstrumented,
# with the same LIBKTX_* options IGL's root CMakeLists.txt sets, for the test build; build.sh rebuilds it
# from the same cached source with the fuzz flags for the fuzz targets. webgpu-headers only provides the enum
# types WgslReflection.h names (IGL_WITH_WEBGPU is off in a desktop build).
USER root
RUN [ -n "$SOURCE_DATE_EPOCH" ] && repro-sources-list.sh || true ; \
    apt-get update && apt-get install -yq --no-install-recommends libgtest-dev \
 && rm -rf /var/lib/apt/lists/*
RUN set -eux; fetch() { d="/opt/toolchains/deps/$1/src"; mkdir -p "$d"; cd "$d"; git init -q; \
      git fetch -q --depth 1 "$2" "$3"; git checkout -q FETCH_HEAD; rm -rf .git; }; \
    fetch stb-8b5f1f3 https://github.com/nothings/stb.git 8b5f1f37b5b75829fc72d38e7b5d4bcbf8a26d55; \
    fetch SPIRV-Headers-cca08c6 https://github.com/KhronosGroup/SPIRV-Headers.git cca08c63cefa129d082abca0302adcb81610b465; \
    fetch ldrutils-3b3788d https://github.com/corporateshark/ldrutils 3b3788dc054f32a2c81c2f8dee7eb7739d53fc02; \
    fetch webgpu-headers-a1dc774 https://github.com/webgpu-native/webgpu-headers a1dc77409bb2b8bd80540cbf4b8db219e123e909; \
    fetch ktx-software-f4acc8d https://github.com/KhronosGroup/KTX-Software.git f4acc8d44a2f2dcacf61878c80e1c4061fc6a5b3; \
    d=/opt/toolchains/deps/ktx-software-f4acc8d; \
    cmake -S "$d/src/lib" -B /tmp/ktx-build -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_FLAGS="-g -gdwarf-3" -DCMAKE_CXX_FLAGS="-g -gdwarf-3" \
      -DBUILD_SHARED_LIBS=OFF -DLIBKTX_VERSION_READ_ONLY=OFF -DLIBKTX_VERSION_FULL=ON \
      -DLIBKTX_FEATURE_KTX1=ON -DLIBKTX_FEATURE_KTX2=ON -DLIBKTX_FEATURE_VK_UPLOAD=OFF \
      -DLIBKTX_FEATURE_GL_UPLOAD=OFF -DLIBKTX_FEATURE_ETC_UNPACK=ON; \
    cmake --build /tmp/ktx-build -j"$(nproc)"; \
    mkdir -p "$d/lib" "$d/include"; find /tmp/ktx-build -name '*.a' -exec cp {} "$d/lib/" \; ; \
    cp -r "$(dirname "$(find "$d/src" -name ktx.h -path "*include*" | head -1)")/." "$d/include/"; rm -rf /tmp/ktx-build; \
    chmod -R a+rX,go-w /opt/toolchains/deps; ls -l "$d/lib"

# Source enters from the build CONTEXT (the CI checkout): the FULL repo (incl. .git
# history) is copied to /mayhem as `mayhem`; build.sh builds in place.
USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

# Anything a Dockerfile step materializes into the tree (downloaded fixtures, generated headers,
# vendored deps) MUST be committed or (re)created by build.sh: rlenv's patch grader runs
# `git clean -ffdX` before every graded build, so a gitignored, untracked file is gone by then and
# every honest patch scores zero (SPEC §6.2 item 16; verify-repo.sh checks it).
#
# OPTIONAL compile-cache pre-fill (SPEC §6.2 item 18). Bases minted with /opt/mayhem/ccache/prefill
# run the build under rlenv's pinned ccache, so the patch grader's first (otherwise cold) rebuild is
# warm — this is what keeps large C/C++ targets inside the build time limit. Older bases fall back to
# the plain build; a missing or stale pre-fill only costs a cold cache. Never enable ccache in
# build.sh or via ENV/PATH, and keep the compiler resolving by name (CC=clang) or nothing is cached.
RUN if [ -x /opt/mayhem/ccache/prefill ]; then /opt/mayhem/ccache/prefill bash mayhem/build.sh; \
    else bash mayhem/build.sh; fi

# Run the project's functional tests at build time IF the repo ships them (mayhem/test.sh is
# optional — omit it only when the repo has no tests meaningful for RL). A failing suite fails the
# image build, so the commit image is guaranteed to build AND pass its own tests.
RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh — repo ships no functional tests"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
