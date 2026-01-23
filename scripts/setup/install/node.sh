#!/bin/bash

if command -v node &> /dev/null && node -v | grep -q "^v${NODE_VERSION}\."; then
  echo "=== Node.js ${NODE_VERSION} 이미 설치됨 (스킵) ==="
  return 0
fi

echo "=== Node.js ${NODE_VERSION} 설치 ==="
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
sudo apt install -y nodejs
