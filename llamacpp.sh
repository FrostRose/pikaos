#!/bin/bash
set -e

# 1. 依赖
sudo nala install -y \
  clang-20 lld-20 llvm-20-dev llvm-20-tools libpolly-20-dev libclang-rt-20-dev libomp-20-dev libllvm20 \
  libopenblas-dev libmimalloc-dev \
  cmake ninja-build ccache pkg-config \
  libcurl4-openssl-dev wget


# 2. 环境
export CC=clang-20
export CXX=clang++-20
echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
sudo rm -f /usr/lib/x86_64-linux-gnu/libmimalloc.so
sudo ln -sf /usr/lib/x86_64-linux-gnu/libmimalloc.so.3.0 /usr/lib/x86_64-linux-gnu/libmimalloc.so
sudo ldconfig

COMPILE_FLAGS="-O3 -DNDEBUG -march=native -mtune=native -mprefer-vector-width=256 \
    -fvectorize -fslp-vectorize -fPIC \
    -mllvm -polly \
    -mllvm -polly-vectorizer=stripmine \
    -mllvm -polly-run-inliner \
    -mllvm -polly-invariant-load-hoisting \
    -mllvm -polly-ast-use-context \
    -mllvm -polly-detect-profitability-min-per-loop-insts=40 \
    -mllvm -inline-threshold=1500 \
    -mllvm -unroll-threshold=750 \
    -fno-math-errno -fno-trapping-math \
    -funroll-loops -fmerge-all-constants \
	-fslp-vectorize \
    -fno-stack-protector -fomit-frame-pointer \
    -fno-plt -fno-semantic-interposition \
    -ffunction-sections -fdata-sections -falign-functions=64 \
    -fforce-enable-int128 -falign-loops=32"

export LDFLAGS="-fuse-ld=lld -lmimalloc \
    -flto=thin -fwhole-program-vtables \
    -Wl,--icf=all -Wl,--gc-sections \
    -Wl,-O3 -Wl,--lto-O3 \
    -Wl,--hash-style=gnu \
    -Wl,--build-id=none \
    -Wl,-z,now -Wl,-z,relro \
    -Wl,--sort-common \
    -Wl,--as-needed"

# 2.1  前置
if [ ! -d "llama.cpp" ]; then
    git clone https://github.com/ggml-org/llama.cpp
fi
cd llama.cpp
rm -rf build

# 3. 编译
cmake -B build -GNinja \
    -DGGML_OPENMP=ON -DBUILD_SHARED_LIBS=OFF \
    -DGGML_NATIVE=ON -DGGML_LTO=ON -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=TRUE \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="$COMPILE_FLAGS" \
    -DCMAKE_CXX_FLAGS="$COMPILE_FLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"
ninja -C build llama-server

# 4. 运行变量
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
    export MIMALLOC_EAGER_COMMIT=1
    export MIMALLOC_PAGE_RESET=0
    $HOME/llama.cpp/build/bin/llama-server "$@"
}
EOF
fi
source ~/.bashrc
