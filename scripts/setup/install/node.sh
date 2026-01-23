#!/bin/bash

echo "=== Node.js ${NODE_VERSION} 설치 ==="
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
sudo apt install -y nodejs
