#!/bin/bash
set -e

# 1. install
sudo apt install -y \
  clang \
  mold \
  libopenblas-dev libmimalloc-dev \
  cmake ninja-build ccache pkg-config \
  libcurl4-openssl-dev git

# 2. clone
if [ ! -d "llama.cpp" ]; then
    git clone --depth=1 https://github.com/ggml-org/llama.cpp
fi

# 3. config
MIMALLOC_LIB=$(find /usr/lib/x86_64-linux-gnu -name "libmimalloc.so" 2>/dev/null | head -n 1)
if [ -z "$MIMALLOC_LIB" ]; then
    echo "⚠️  未找到 libmimalloc.a,使用动态链接"
    MIMALLOC_LIB="-lmimalloc"
fi

OPENBLAS_LIB=$(find /usr/lib -name "libopenblas.a" 2>/dev/null | head -n 1)
if [ -z "$OPENBLAS_LIB" ]; then
    echo "⚠️  未找到 libopenblas.a,使用 pkg-config"
    OPENBLAS_LIB=$(pkg-config --libs openblas)
fi

export CC=clang
export CXX=clang++
export COMMON_FLAGS="-fno-math-errno -fno-trapping-math"
export CFLAGS="$COMMON_FLAGS"
export CXXFLAGS="$COMMON_FLAGS"
export LDFLAGS="-fuse-ld=mold -Wl,-s -Wl,--gc-sections $MIMALLOC_LIB"

# 4. build
cd llama.cpp
rm -rf build

echo "BLAS+openmp会变慢所以关闭"
cmake -B build -G Ninja \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_STATIC=ON \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -DGGML_NATIVE=ON \
    -DGGML_BLAS=ON \
    -DGGML_BLAS_VENDOR=OpenBLAS \
    -DBLAS_LIBRARIES="$OPENBLAS_LIB;-lm;-lpthread" \
    -DGGML_OPENMP=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"

ninja -C build llama-server llama-cli

# 5. env
echo "不设置blas线程或者限制为1速度最快"

if ! grep -q "function llama-server()" ~/.bashrc; then
cat << 'EOF' >> ~/.bashrc

# ── llama.cpp ──
function llama-server() {
    export MIMALLOC_PAGE_RESET=0
    export MIMALLOC_LARGE_OS_PAGES=0
    export MIMALLOC_ARENA_EAGER_COMMIT=0
    #export OPENBLAS_NUM_THREADS=1
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
