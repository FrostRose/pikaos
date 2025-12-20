#!/bin/bash
# Llama.cpp Direct Installer (Clean Version)

set -e

# 1. Install Dependencies
echo ">> Installing dependencies..."
sudo apt update
sudo apt install -y \
  build-essential \
  ccache \
  cmake \
  git \
  pkg-config \
  libcurl4-openssl-dev \
  libopenblas-dev \
  libjemalloc-dev \
  mold \
  ninja-build

# 2. Setup Environment
echo ">> Writing configuration to .bashrc..."

cat >> ~/.bashrc << 'EOF'

# llama.cpp specific env
export CC="ccache gcc"
export CXX="ccache g++"
export GOMP_CPU_AFFINITY=0-$(($(nproc) - 1))
export OPENBLAS_NUM_THREADS=$(nproc)
export PATH=$HOME/llama.cpp/build/bin:$PATH
export HF_ENDPOINT=https://hf-mirror.com
EOF

# 3. Clone and Build
echo ">> Cloning/Updating llama.cpp..."
if [ ! -d "$HOME/llama.cpp" ]; then
    git clone https://github.com/ggml-org/llama.cpp "$HOME/llama.cpp"
fi
cd "$HOME/llama.cpp"

# 4. Build Setup
echo ">> Running CMake..."
CC="ccache gcc" CXX="ccache g++" cmake -B build \
  -DGGML_LTO=ON \
  -DGGML_BLAS=ON \
  -DGGML_BLAS_VENDOR=OpenBLAS \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=mold -ljemalloc -s -Wl,--gc-sections" \
  -G Ninja

# 5. Build
echo ">> Compiling with Ninja..."
ninja -C build llama-cli llama-server

# 6. Interactive Permissions (Final step)
echo "-------------------------------------------------------"
read -p "Enable memlock for better performance? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ">> Configuring /etc/security/limits.conf..."
    echo -e "$USER soft memlock unlimited\n$USER hard memlock unlimited" | sudo tee -a /etc/security/limits.conf
    echo ">> Success. Memlock will be active after RE-LOGIN."
fi

echo "-------------------------------------------------------"
echo ">> Done. Please RE-LOGIN or run 'source ~/.bashrc' to finalize."
