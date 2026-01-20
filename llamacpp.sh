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
if [ -f "/usr/lib/x86_64-linux-gnu/libmimalloc.so.3.0" ]; then
    sudo ln -sf /usr/lib/x86_64-linux-gnu/libmimalloc.so.3.0 /usr/lib/x86_64-linux-gnu/libmimalloc.so
    sudo ldconfig
fi


# 3. 编译标志
COMMON_FLAGS="-march=native -mtune=native -mprefer-vector-width=512 \
    -O3 -DNDEBUG \
    -flto=thin \
    -fwhole-program-vtables \
    -ffp-contract=fast \
    -fno-math-errno \
    -fno-trapping-math \
    -fno-signed-zeros \
    -fstrict-vtable-pointers \
    -fno-stack-protector \
    -funroll-loops \
    -falign-functions=64 \
    -fvisibility=hidden \
    -fvectorize -fslp-vectorize \
    -fmerge-all-constants \
    -fomit-frame-pointer \
    -fno-plt -fno-semantic-interposition \
    -ffunction-sections -fdata-sections -falign-loops=32 \
    -fforce-enable-int128 \
    -fvisibility-inlines-hidden"
POLLY_FLAGS="-mllvm -polly \
    -mllvm -polly-vectorizer=stripmine \
    -mllvm -polly-run-inliner \
    -mllvm -polly-invariant-load-hoisting \
    -mllvm -polly-ast-use-context \
    -mllvm -polly-parallel=false \
    -mllvm -polly-detect-profitability-min-per-loop-insts=40 \
    -mllvm -inline-threshold=1500 \
    -mllvm -unroll-threshold=750 \
    -mllvm -enable-gvn-hoist \
    -mllvm -enable-load-pre \
    -mllvm -enable-loop-distribute \
    -mllvm -aggressive-ext-opt \
    -mllvm -extra-vectorizer-passes \
    -mllvm -slp-vectorize-hor \
    -mllvm -slp-max-look-ahead-depth=8 \
    -mllvm -rotation-max-header-size=32 \
    -mllvm -hexagon-loop-prefetch \
    -mllvm -prefetch-distance=128 \
    -mllvm -enable-loop-versioning-licm"
export CFLAGS="$COMMON_FLAGS $POLLY_FLAGS"
export CXXFLAGS="$COMMON_FLAGS $POLLY_FLAGS"
export LDFLAGS="-fuse-ld=lld -lmimalloc \
    -flto=thin -fwhole-program-vtables \
    -Wl,--icf=all -Wl,--gc-sections \
    -Wl,-O3 -Wl,--lto-O3 \
    -Wl,--hash-style=gnu \
    -Wl,--build-id=none \
    -Wl,-z,now -Wl,-z,relro \
    -Wl,--sort-common \
    -Wl,--as-needed"

# 4. 源码拉取
if [ ! -d "llama.cpp" ]; then
    git clone https://github.com/ggml-org/llama.cpp
fi
cd llama.cpp
rm -rf build


# 5. 构建指令
cmake -B build -GNinja \
    -DGGML_OPENMP=ON -DBUILD_SHARED_LIBS=OFF \
    -DGGML_NATIVE=ON \
    -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"

ninja -C build llama-server llama-cli


# 6. 运行配置
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
echo "编译完成！Clang-20 + ThinLTO + Polly + OpenBLAS 已就绪。"
echo "请执行 'source ~/.bashrc' 加载环境。"
echo "使用 'llamacpp -m model.gguf ...' 启动 server"
echo "使用 'llamacpp cli -m model.gguf ...' 启动 cli"
echo "-------------------------------------------------------"
