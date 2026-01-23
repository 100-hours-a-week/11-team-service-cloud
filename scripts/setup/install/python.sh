#!/bin/bash

echo "=== Python ${PYTHON_VERSION} 설치 ==="
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update
sudo apt install -y python${PYTHON_VERSION}

echo "=== uv 설치 ==="
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
