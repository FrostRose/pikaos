#!/bin/bash
set -e

# 1. 依赖
sudo nala update
sudo nala install -y \
  clang-21 lld-21 llvm-21-dev llvm-21-tools libpolly-21-dev libclang-rt-21-dev libomp-21-dev libllvm21 \
  libopenblas-dev libmimalloc-dev \
  cmake ninja-build ccache pkg-config \
  libcurl4-openssl-dev wget

# 2. 环境配置
export CC=clang-21
export CXX=clang++-21
echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
if [ -f "/usr/lib/x86_64-linux-gnu/libmimalloc.so.3.0" ]; then
    sudo ln -sf /usr/lib/x86_64-linux-gnu/libmimalloc.so.3.0 /usr/lib/x86_64-linux-gnu/libmimalloc.so
    sudo ldconfig
fi

# 3. 编译标志
COMMON_FLAGS="-march=native -mtune=native \
    -O3 -DNDEBUG \
    -flto=thin \
    -fwhole-program-vtables \
    -fno-plt \
    -fno-stack-protector \
    -ffunction-sections -fdata-sections \
    -fvisibility=hidden -fvisibility-inlines-hidden"
MATH_FLAGS="-fno-math-errno \
    -fno-trapping-math \
    -fno-signed-zeros \
    -ffp-contract=fast"
POLLY_FLAGS="-mllvm -polly \
    -mllvm -polly-parallel=false \
    -mllvm -polly-invariant-load-hoisting \
    -mllvm -polly-ast-use-context"
export CFLAGS="$COMMON_FLAGS $MATH_FLAGS $POLLY_FLAGS"
export CXXFLAGS="$COMMON_FLAGS $MATH_FLAGS $POLLY_FLAGS"
export LDFLAGS="-fuse-ld=lld-21 -lmimalloc \
    -flto=thin -fwhole-program-vtables \
    -Wl,--icf=all -Wl,--gc-sections \
    -Wl,-O3 -Wl,--lto-O3 \
    -Wl,--build-id=none \
    -Wl,-z,now -Wl,-z,relro \
    -Wl,--as-needed"

# 4. 前置
if [ ! -d "llama.cpp" ]; then
    git clone https://github.com/ggml-org/llama.cpp
fi
cd llama.cpp
rm -rf build

# 5. 编译
cmake -B build -GNinja \
    -DGGML_OPENMP=ON -DBUILD_SHARED_LIBS=OFF \
    -DGGML_NATIVE=ON \
    -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"
ninja -C build llama-server llama-cli

# 6. 环境
if ! grep -q "function llamacpp()" ~/.bashrc; then
cat << 'EOF' >> ~/.bashrc

function llamacpp() {
    local PHY_CORES=$(lscpu -b -p=Core,Socket | grep -v '^#' | sort -u | wc -l)
    export OPENBLAS_NUM_THREADS=$PHY_CORES
    export OMP_NUM_THREADS=$PHY_CORES
    export OMP_PROC_BIND=TRUE
    export OMP_PLACES=CORES
    export OMP_WAIT_POLICY=ACTIVE
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

# 7. 完成
echo "-------------------------------------------------------"
echo "编译完成！"
echo "编译器: Clang-21 (配合 Polly + ThinLTO)"
echo "-------------------------------------------------------"
echo "请执行 'source ~/.bashrc' 加载环境。"
