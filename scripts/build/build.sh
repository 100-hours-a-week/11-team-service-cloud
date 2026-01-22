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
cd /home/ubuntu/fastAPI
git pull
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
pip install fastapi uvicorn

echo "=== 빌드 완료 ==="