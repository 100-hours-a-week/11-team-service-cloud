#!/bin/bash

if command -v python${PYTHON_VERSION} &> /dev/null; then
  echo "=== Python ${PYTHON_VERSION} 이미 설치됨 (스킵) ==="
else
  echo "=== Python ${PYTHON_VERSION} 설치 ==="
  sudo add-apt-repository ppa:deadsnakes/ppa -y
  sudo apt update
  sudo apt install -y python${PYTHON_VERSION}
fi

if command -v uv &> /dev/null; then
  echo "=== uv 이미 설치됨 (스킵) ==="
else
  echo "=== uv 설치 ==="
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

export PATH="$HOME/.local/bin:$PATH"
