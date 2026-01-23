#!/bin/bash

# 프론트엔드 빌드
echo "=== 프론트엔드 빌드 시작 ==="
cd /home/ubuntu/frontend
git pull
npm install
npm run build

# 백엔드 빌드
echo "=== 백엔드 빌드 시작 ==="
cd /home/ubuntu/backend
git pull
./gradlew build

# FastAPI 설정
echo "=== FastAPI 설정 시작 ==="
cd /home/ubuntu/ai

# uv 설치 (없으면)
if ! command -v uv &> /dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

uv sync

echo "=== 빌드 완료 ==="