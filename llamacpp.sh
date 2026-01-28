#!/bin/bash
set -e

# 1. 依赖 包管理器的llvm比高版本预编译包的编译产物性能更高
sudo nala update
sudo nala install -y \
  clang-21 llvm-21-dev \
  mold \
  libopenblas-dev libmimalloc-dev \
  cmake ninja-build ccache pkg-config \
  libcurl4-openssl-dev wget

# 1.5 前置
if [ ! -d "llama.cpp" ]; then
    git clone https://github.com/ggml-org/llama.cpp
fi

# 2. 环境配置
export CC=clang
export CXX=clang++
echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
if [ -f "/usr/lib/x86_64-linux-gnu/libmimalloc.so.3.0" ]; then
    sudo ln -sf /usr/lib/x86_64-linux-gnu/libmimalloc.so.3.0 /usr/lib/x86_64-linux-gnu/libmimalloc.so
    sudo ldconfig
fi

# 3. 编译标志 不支持-mllvm -enable-ml-inliner=release
COMMON_FLAGS="-DNDEBUG -flto=thin -fno-plt -ffunction-sections -fdata-sections -fvisibility=hidden"
OP_FLAGS="-ffast-math -fno-finite-math-only -fno-math-errno -ffp-contract=fast -mllvm -polly -fstrict-aliasing"
export CFLAGS="$COMMON_FLAGS $OP_FLAGS"
export CXXFLAGS="$COMMON_FLAGS $OP_FLAGS"
export LDFLAGS="-fuse-ld=mold -lmimalloc -flto=thin -Wl,--icf=all -Wl,--gc-sections"

# 4. 编译
cd llama.cpp
rm -rf build
cmake -B build -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_NATIVE=ON \
    -DGGML_OPENMP=ON \
    -DGGML_BLAS=ON \
    -DGGML_BLAS_VENDOR=OpenBLAS \
    -DGGML_CCACHE=ON \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"

ninja -C build llama-server llama-cli

# 5. 运行环境
if ! grep -q "function llamacpp()" ~/.bashrc; then
cat << 'EOF' >> ~/.bashrc

# llama.cpp
function llamacpp() {
    local PHY_CORES=$(lscpu -b -p=Core,Socket | grep -v '^#' | sort -u | wc -l)
    export OPENBLAS_NUM_THREADS=$PHY_CORES
    export OMP_NUM_THREADS=$PHY_CORES
    export MIMALLOC_LARGE_OS_PAGES=1
    if [[ "$1" == "cli" ]]; then
        shift
        $HOME/llama.cpp/build/bin/llama-cli "$@"
    else
        $HOME/llama.cpp/build/bin/llama-server "$@"
    fi
}
EOF
fi

echo "-------------------------------------------------------"
echo "构建完成！"
echo "请执行 'source ~/.bashrc' 加载环境。"
