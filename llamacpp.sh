#!/bin/bash
set -e

# ─── 1. 依赖 ─────────────────────────────────────────────────────────
sudo apt install -y \
  clang-21 llvm-21-dev \
  mold \
  libopenblas-dev libmimalloc-dev \
  cmake ninja-build ccache pkg-config \
  libcurl4-openssl-dev git \
  hwloc

# ─── 2. 前置：shallow clone ──────────────────────────────────────────
if [ ! -d "llama.cpp" ]; then
    git clone --depth=1 https://github.com/ggml-org/llama.cpp
fi

# ─── 3. 编译器与路径 ─────────────────────────────────────────────────
export CC=clang-21
export CXX=clang++-21
export COMMON_FLAGS="-fno-math-errno -fno-trapping-math -falign-functions=64"
export CFLAGS="$COMMON_FLAGS"
export CXXFLAGS="$COMMON_FLAGS"
MIMALLOC_STATIC=$(find /usr/lib -name "libmimalloc.a" 2>/dev/null | head -n 1)
if [ -n "$MIMALLOC_STATIC" ]; then
    EXT_LIBS="$MIMALLOC_STATIC"
else
    EXT_LIBS="-l:libmimalloc.so"
fi
export LDFLAGS="-fuse-ld=mold -flto=thin -Wl,--icf=all -Wl,--gc-sections $EXT_LIBS"

OPENBLAS_LIB="/usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblas.a"
OPENBLAS_INC="/usr/include"

# ─── 4. 构建 ─────────────────────────────────────────────────────────
cd llama.cpp

rm -rf build

cmake -B build -G Ninja \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_STATIC=ON \
    -DGGML_LTO=ON \
    -DGGML_NATIVE=ON \
    -DGGML_BLAS=ON \
    -DGGML_BLAS_VENDOR=OpenBLAS \
    -DBLAS_LIBRARIES="$OPENBLAS_LIB;-lm;-lpthread" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"

ninja -C build llama-server llama-cli

# ─── 5. 环境 ─────────────────────────────────────────────────
if ! grep -q "function llama-server()" ~/.bashrc; then
cat << 'EOF' >> ~/.bashrc

# ── llama.cpp ──
function llama-server() {
    local PHY_CORES=$(hwloc-calc --number-of core all 2>/dev/null || nproc --all)
    export OMP_NUM_THREADS=$PHY_CORES
    export OPENBLAS_NUM_THREADS=$PHY_CORES
    export OMP_PROC_BIND=close
    export OMP_PLACES=cores
    export MIMALLOC_LARGE_OS_PAGES=1
    export MIMALLOC_USE_HUGE_OS_PAGES=1
    export MIMALLOC_EAGER_COMMIT=1
    if [[ "$1" == "cli" ]]; then
        shift
        "$HOME/llama.cpp/build/bin/llama-cli" "$@"
    else
        "$HOME/llama.cpp/build/bin/llama-server" "$@"
    fi
}
EOF
fi

echo "───────────────────────────────────────────────"
echo " 构建完成!"
echo " 请执行 source ~/.bashrc 加载环境"
echo "───────────────────────────────────────────────"
