#!/bin/bash

# =============================================
# .env 로드
# =============================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."
INSTALL_DIR="${SCRIPT_DIR}/install"
CONFIG_DIR="${SCRIPT_DIR}/config"

if [ ! -f "${PROJECT_ROOT}/.env" ]; then
  echo "ERROR: .env 파일이 없습니다. .env.example을 참고하여 .env를 생성해주세요."
  exit 1
fi

set -a
source "${PROJECT_ROOT}/.env"
set +a

# =============================================
# 실행
# =============================================
echo "=== 패키지 업데이트 ==="
sudo apt update && sudo apt upgrade -y

echo "=== Git 설치 ==="
sudo apt install -y git

echo "=== 프로젝트 클론 ==="
cd /home/ubuntu
git clone ${FRONTEND_REPO} frontend
git clone ${BACKEND_REPO} backend
git clone ${FASTAPI_REPO} ai

# 개별 설치 스크립트 실행
source ${INSTALL_DIR}/nginx.sh
source ${INSTALL_DIR}/java.sh
source ${INSTALL_DIR}/node.sh
source ${INSTALL_DIR}/python.sh
ource ${INSTALL_DIR}/aws-cli.sh

# 설정 적용
source ${CONFIG_DIR}/nginx.sh

echo "=== 소스코드 및 개발 환경 설치 완료 ==="
