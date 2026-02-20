#!/bin/bash
set -euo pipefail

# 1. install
sudo apt install -y \
  clang \
  mold \
  libmimalloc-dev \
  cmake ninja-build ccache \
  libcurl4-openssl-dev \
  git

# 2. clone
if [ ! -d "llama.cpp" ]; then
    git clone --depth=1 https://github.com/ggml-org/llama.cpp
fi

# 3. build

#可用的额外优化
#  小风险有收益 -fno-math-errno -fno-trapping-math -fno-signed-zeros -freciprocal-math -fapprox-func \
#  收益极小可开可不开 -fno-semantic-interposition -fno-plt \
#  风险大收益明显 -Ofast/-O3 -ffast-math \
#  无风险但是需要编译 编译器时开启 -mllvm -机器学习内联 \
#  负优化 -mllvm -polly

cd llama.cpp
rm -rf build
cmake -B build -G Ninja \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=mold -Wl,--lto-O3 -Wl,--icf=all -Wl,--gc-sections" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=ON \
    -DGGML_STATIC=ON \
    -DGGML_OPENMP=OFF
ninja -C build llama-server

# 4. env
grep -q 'llama-server()' ~/.bashrc || cat <<'EOF' >> ~/.bashrc

#llama.cpp
llama-server() {
    local cmd="$HOME/llama.cpp/build/bin/llama-server"
    local MIMALLOC_LIB=$(find /usr/lib/x86_64-linux-gnu -name "libmimalloc.so" 2>/dev/null | head -n 1)
    LD_PRELOAD="$MIMALLOC_LIB" \
    MIMALLOC_PAGE_RESET=0 \
    MIMALLOC_ALLOW_LARGE_OS_PAGES=1 \
    MIMALLOC_EAGER_COMMIT=1 \
    MIMALLOC_PURGE_DELAY=-1 \
    "$cmd" "$@"
}
EOF

echo "───────────────────────────────────────────────"
echo " 构建完成!"
echo " 请执行 source ~/.bashrc 加载环境"
echo "───────────────────────────────────────────────"
