#!/bin/bash
set -e

# 1. install
sudo apt install -y \
  clang \
  mold \
  libmimalloc-dev \
  cmake ninja-build ccache pkg-config \
  libcurl4-openssl-dev git

# 2. clone
if [ ! -d "llama.cpp" ]; then
    git clone --depth=1 https://github.com/ggml-org/llama.cpp
fi

# 3. config
echo "vm.nr_hugepages = 1024" | sudo tee /etc/sysctl.d/90-hugepages.conf >/dev/null
sudo sysctl -p /etc/sysctl.d/90-hugepages.conf >/dev/null

MIMALLOC_LIB=$(find /usr/lib/x86_64-linux-gnu -name "libmimalloc.so" 2>/dev/null | head -n 1)
export CC="ccache clang"
export CXX="ccache clang++"
export COMMON_FLAGS="-march=native -mtune=native -O3 \
    -fno-math-errno -fno-trapping-math \
    -fno-semantic-interposition \
    -flto=thin"
export CFLAGS="$COMMON_FLAGS"
export CXXFLAGS="$COMMON_FLAGS"
export LDFLAGS="-fuse-ld=mold \
    -Wl,--threads \
    -Wl,-O3,--icf=all,--gc-sections \
    $MIMALLOC_LIB"

# 4. build
cd llama.cpp
rm -rf build
cmake -B build -G Ninja \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_STATIC=ON \
    -DGGML_OPENMP=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"
ninja -C build llama-server llama-cli

# 5. env
grep -q 'llama_server()' ~/.bashrc || cat <<'EOF' >> ~/.bashrc

#llama.cpp
llama-server() {
    export MIMALLOC_PAGE_RESET=0
    export MIMALLOC_LARGE_OS_PAGES=1
    export MIMALLOC_RESERVE_HUGE_PAGES=1024
    if [[ "$1" == "cli" ]]; then
        shift
        "$HOME/llama.cpp/build/bin/llama-cli" "$@" --numa distribute
    else
        "$HOME/llama.cpp/build/bin/llama-server" "$@" --numa distribute
    fi
}
EOF

echo "───────────────────────────────────────────────"
echo " 构建完成!"
echo " 请执行 source ~/.bashrc 加载环境"
echo "───────────────────────────────────────────────"
