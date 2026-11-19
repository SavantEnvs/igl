#!/usr/bin/env bash
#
# mayhem/build.sh — build this repo's fuzz harness(es). EDIT per repo.
#
# Runs inside the commit image (mayhem/Dockerfile) as `mayhem` in /mayhem. The base image
# (ghcr.io/savantenvs/base) already exports the build contract — use these, don't redefine:
#   CC, CXX             stock clang / clang++
#   LIB_FUZZING_ENGINE  -fsanitize=fuzzer   (link into each harness that has a LLVMFuzzer entry)
#   SANITIZER_FLAGS     -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer
#                       (ASan + UBSan, both set to HALT — so Mayhem catches memory AND UB defects)
#   DEBUG_FLAGS         -g -gdwarf-3   (DWARF debug info — always on for fuzz/standalone builds,
#                       independent of the sanitizer off-switch; DWARF version must be < 4)
#   RUST_DEBUG_FLAGS    -C debuginfo=2 -C force-frame-pointers=yes -C llvm-args=-gdwarf-3
#                       (thread through RUSTFLAGS on every cargo-fuzz build)
#   GO_DEBUG_FLAGS      -gcflags=all=-N -l
#                       (thread through go build / go-fuzz-build so the linked ELF keeps symbols)
#   SRC                 /mayhem (the repo source)
#
# Contract: build EVERYTHING here — one runnable binary per fuzz harness, AND the project's test
# suite (so mayhem/test.sh only has to RUN it, never compile). Keep it ADDITIVE (build upstream as
# upstream documents; don't edit upstream files). IMPORTANT: build the PROJECT ITSELF with
# $SANITIZER_FLAGS and $DEBUG_FLAGS (not just the harness) so the fuzzed code is instrumented
# AND carries DWARF < 4 symbols — otherwise ASan/UBSan only see the harness, not the library
# you're trying to find bugs in, and backtraces won't resolve project source lines. Build the TEST
# suite with the project's NORMAL flags (a clean, independent build) so test.sh stays an honest
# functional oracle and won't false-fail on benign UB. Leave the test binary/runner where test.sh
# expects it.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — it must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build knobs come from the ENVIRONMENT (overridable), with sane defaults — no if-statements,
# just parameter-expansion fallbacks. Default sanitizers are the base's ASan+UBSan (halting); override
# per build via the Dockerfile's `--build-arg SANITIZER_FLAGS="..."`.
# NB: SANITIZER_FLAGS uses `=` (no colon) on purpose — `=` only fills when the var is UNSET, so an
# explicit EMPTY value (`--build-arg SANITIZER_FLAGS=`) is honored and builds with NO sanitizers
# (useful when you want the program's natural crash / full backtrace, not an ASan report). The other
# knobs use `:=` (default on empty too). MAYHEM_JOBS sets build parallelism (falls back to nproc).
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
# DEBUG_FLAGS carries DWARF debug info INDEPENDENTLY of the sanitizer off-switch (so an empty
# SANITIZER_FLAGS still yields DWARF symbols). DWARF MUST be < 4 (Mayhem triage can't read >=4); clang-19's
# plain `-g` emits DWARF-5, so `-gdwarf-3` is explicit. Apply $DEBUG_FLAGS to the fuzz/harness/standalone
# builds (NOT the test/oracle build). Rust/Go carry the same intent via their language flags below.
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${RUST_DEBUG_FLAGS:=-C debuginfo=2 -C force-frame-pointers=yes -C llvm-args=-gdwarf-3}"
: "${GO_DEBUG_FLAGS:=-gcflags=all=-N -l}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
# COVERAGE_FLAGS: empty by default → no effect on the normal oracle build. Set it via the Dockerfile's
# `--build-arg COVERAGE_FLAGS="-fprofile-instr-generate -fcoverage-mapping"` to instrument the TEST
# build for source-coverage measurement (how much of the project the test suite actually exercises —
# a quality signal for the oracle; complements the anti-reward-hack sabotage check). APPEND it to the
# test build's compile+link flags in step 3 (NOT the fuzz build); after `test.sh` runs, merge with
# `llvm-profdata` and report with `llvm-cov`. Empty value is honored (`=`, not `:=`).
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS RUST_DEBUG_FLAGS GO_DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# IGL's CMake build clones ~30 dependencies at configure time (deploy_deps.py) and requires a GPU
# backend (Vulkan/GL/Metal) to configure at all. The fuzzed code is the device-free part: the IGLU
# texture loaders (KTX1/KTX2 via libktx, PNG/JPEG/HDR via stb), the SPIR-V reflection/specialization
# walkers and the WGSL reflection parser. build.sh compiles exactly those upstream sources (plus the
# igl core files they link against) directly, with the dependencies the Dockerfile pinned under
# /opt/toolchains/deps (same revisions as third-party/bootstrap-deps.json).
DEPS=/opt/toolchains/deps
KTX="$DEPS/ktx-software-f4acc8d"
OUT_FUZZ="$SRC/build/mayhem-fuzz"     # build/ is gitignored upstream
OUT_TEST="$SRC/build/mayhem-test"
mkdir -p "$OUT_FUZZ" "$OUT_TEST" "$SRC/build/mayhem-inc/webgpu"
# WgslReflection.h includes <webgpu/webgpu.h> for its enum types only.
cp -f "$DEPS/webgpu-headers-a1dc774/src/webgpu.h" "$SRC/build/mayhem-inc/webgpu/webgpu.h"
# IGL includes ldrutils as <ldrutils/lutils/...>.
ln -sfn "$DEPS/ldrutils-3b3788d/src" "$SRC/build/mayhem-inc/ldrutils"

INCLUDES=(-I"$SRC" -I"$SRC/src" -I"$SRC/build/mayhem-inc" -I"$DEPS/stb-8b5f1f3/src"
          -I"$DEPS/SPIRV-Headers-cca08c6/src/include" -I"$KTX/include" -I"$KTX/src/external/dfdutils")
DEFS=(-DIGL_CMAKE_BUILD=1)
KTX_LIBS=("$KTX/lib/libktx.a" "$KTX/lib/libbasisu_encoder.a" "$KTX/lib/libastcenc-avx2-static.a")

# Upstream library sources (what IGLLibrary + IGLUtexture_loader + IGLstb compile for these parsers).
mapfile -t LIB_CXX < <(
  ls src/igl/*.cpp
  echo src/igl/opengl/util/TextureFormat.cpp
  echo src/igl/vulkan/util/TextureFormat.cpp
  echo src/igl/vulkan/util/SpvReflection.cpp
  echo src/igl/vulkan/util/SpvConstantSpecialization.cpp
  echo src/igl/webgpu/WgslReflection.cpp
  find IGLU/texture_loader -name '*.cpp' -not -path '*/tests/*' | sort
)
LIB_C=(third-party/deps/patches/stb_impl/stb_image.c)

# compile_lib <outdir> <cflags...>: one object per source (by name through PATH, ccache-friendly),
# then a static archive <outdir>/libigl_parsers.a.
compile_lib() {
  local out="$1"; shift
  local flags=("$@")
  rm -f "$out"/obj/*.o "$out/libigl_parsers.a"
  mkdir -p "$out/obj"
  printf '%s\n' "${LIB_CXX[@]}" | xargs -P "$MAYHEM_JOBS" -I{} bash -c \
    'o="$0/obj/$(echo "$1" | tr / _).o"; exec '"$CXX"' -std=c++20 -c "$1" -o "$o" "${@:2}"' \
    "$out" {} "${flags[@]}" "${DEFS[@]}" "${INCLUDES[@]}"
  for f in "${LIB_C[@]}"; do
    $CC -c "$f" -o "$out/obj/$(echo "$f" | tr / _).o" "${flags[@]}" "${DEFS[@]}" "${INCLUDES[@]}"
  done
  ar rcs "$out/libigl_parsers.a" "$out"/obj/*.o
}

# 1) The parsers, instrumented. IGL_DEBUG=0 is the release configuration of IGL (Config.h lets the
#    build system set it): with IGL_DEBUG=1 every IGL_DEBUG_ABORT on a malformed file raises SIGTRAP
#    (a developer breakpoint, not an error path), so every invalid input would "crash". The library's
#    own error handling (igl::Result) and libc assert() stay as they are.
# -fsanitize=fuzzer-no-link: SanCov edge instrumentation on the parsers and harnesses (the base's
# LIB_FUZZING_ENGINE only adds libFuzzer at link time).
FUZZ_FLAGS=($SANITIZER_FLAGS $DEBUG_FLAGS -O1 -fsanitize=fuzzer-no-link -DIGL_DEBUG=0)
compile_lib "$OUT_FUZZ" "${FUZZ_FLAGS[@]}"

# libktx is where most of the KTX1/KTX2 parsing happens (header, DFD and level-index checks,
# supercompression, the Basis transcoder), so the fuzz build instruments it too: rebuilt out of tree
# from the pinned source the Dockerfile cached, with the same flags as the parsers and the same
# LIBKTX_* options IGL's root CMakeLists.txt sets. *_FLAGS_RELEASE is emptied so CMake's
# -O3 -DNDEBUG doesn't hide libktx's own asserts. The test build keeps the uninstrumented
# /opt/toolchains/deps copy.
# One UBSan check is relaxed, for libktx only: -fno-sanitize=function. libktx's C "vtable" stores
# e.g. ktxTexture1_NeedsTranscoding(ktxTexture1*) in a slot typed bool (*)(ktxTexture*) by design,
# and every call through it (ktxTexture_NeedsTranscoding() in IGLU's ktx/TextureLoaderFactory.cpp
# and libktx's own dispatch) would report "call through pointer to incorrect function type" on
# every valid KTX1 file. Without the callee-side type signature the check is skipped; ASan and the
# rest of UBSan stay on and halting in libktx, and -fsanitize=function stays on for IGL's code.
KTX_FUZZ="$SRC/build/mayhem-ktx-fuzz"
KTX_FUZZ_FLAGS="${FUZZ_FLAGS[*]} -fno-sanitize=function"
cmake -S "$KTX/src/lib" -B "$KTX_FUZZ" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="$KTX_FUZZ_FLAGS" -DCMAKE_CXX_FLAGS="$KTX_FUZZ_FLAGS" \
  -DCMAKE_C_FLAGS_RELEASE= -DCMAKE_CXX_FLAGS_RELEASE= \
  -DBUILD_SHARED_LIBS=OFF -DLIBKTX_VERSION_READ_ONLY=OFF -DLIBKTX_VERSION_FULL=ON \
  -DLIBKTX_FEATURE_KTX1=ON -DLIBKTX_FEATURE_KTX2=ON -DLIBKTX_FEATURE_VK_UPLOAD=OFF \
  -DLIBKTX_FEATURE_GL_UPLOAD=OFF -DLIBKTX_FEATURE_ETC_UNPACK=ON
cmake --build "$KTX_FUZZ" -j"$MAYHEM_JOBS"
KTX_FUZZ_LIBS=()
for l in "${KTX_LIBS[@]}"; do
  f="$(find "$KTX_FUZZ" -name "$(basename "$l")" | head -1)"
  [ -f "$f" ] || { echo "build.sh: instrumented $(basename "$l") not built" >&2; exit 1; }
  KTX_FUZZ_LIBS+=("$f")
done
$CXX ${SANITIZER_FLAGS} ${DEBUG_FLAGS} -c "$SRC/mayhem/lsan_off.cc" -o "$OUT_FUZZ/lsan_off.o"
$CC ${SANITIZER_FLAGS} ${DEBUG_FLAGS} -c "$STANDALONE_FUZZ_MAIN" -o "$OUT_FUZZ/standalone_main.o"

# 2) Harnesses: libFuzzer binary + run-once standalone reproducer each.
for h in fuzz_ktx1 fuzz_ktx2 fuzz_stb_image fuzz_spirv_reflection fuzz_wgsl_reflection; do
  $CXX -std=c++20 "${FUZZ_FLAGS[@]}" "${DEFS[@]}" "${INCLUDES[@]}" -c "$SRC/mayhem/harnesses/$h.cpp" -o "$OUT_FUZZ/$h.o"
  $CXX "${FUZZ_FLAGS[@]}" $LIB_FUZZING_ENGINE "$OUT_FUZZ/$h.o" "$OUT_FUZZ/lsan_off.o" \
    "$OUT_FUZZ/libigl_parsers.a" "${KTX_FUZZ_LIBS[@]}" -lpthread -lm -o "$SRC/$h"
  $CXX "${FUZZ_FLAGS[@]}" "$OUT_FUZZ/standalone_main.o" "$OUT_FUZZ/$h.o" "$OUT_FUZZ/lsan_off.o" \
    "$OUT_FUZZ/libigl_parsers.a" "${KTX_FUZZ_LIBS[@]}" -lpthread -lm -o "$SRC/$h-standalone"
done

# 3) Upstream's own gtest suites for these parsers, with normal (unsanitized) flags. Device-free
#    tests only: the texture loaders, IData/DataReader, SPIR-V constant specialization, WGSL reflection.
TEST_FLAGS=(-O1 -g -DIGL_DEBUG=0 $COVERAGE_FLAGS)
compile_lib "$OUT_TEST" "${TEST_FLAGS[@]}"
TESTS=(
  src/igl/tests/iglu/texture_loader/Ktx1TextureLoaderTest.cpp
  src/igl/tests/iglu/texture_loader/Ktx2TextureLoaderTest.cpp
  src/igl/tests/iglu/texture_loader/StbPngTextureLoaderTest.cpp
  src/igl/tests/iglu/texture_loader/StbJpegTextureLoaderTest.cpp
  src/igl/tests/iglu/texture_loader/StbHdrTextureLoaderTest.cpp
  src/igl/tests/iglu/texture_loader/IDataTest.cpp
  IGLU/texture_loader/tests/DataReaderTest.cpp
  src/igl/tests/vulkan/SpvConstantSpecializationTest.cpp
  src/igl/tests/webgpu/WgslReflectionTest.cpp
  src/igl/webgpu/RenderPipelineReflection.cpp
)
rm -f "$OUT_TEST"/t_*.o
for t in "${TESTS[@]}"; do
  $CXX -std=c++20 "${TEST_FLAGS[@]}" "${DEFS[@]}" "${INCLUDES[@]}" -c "$t" -o "$OUT_TEST/t_$(echo "$t" | tr / _).o"
done
$CXX "${TEST_FLAGS[@]}" "$OUT_TEST"/t_*.o "$OUT_TEST/libigl_parsers.a" "${KTX_LIBS[@]}" \
  -lgtest -lgtest_main -lpthread -lm -o "$OUT_TEST/igl_parser_tests"
echo "build.sh: done"
