#!/bin/bash

# =============================================
# 변수 설정 (수정 필요)
# =============================================
export FRONTEND_REPO="https://github.com/100-hours-a-week/11-team-service-fe"
export BACKEND_REPO="https://github.com/100-hours-a-week/11-team-service-be"
export FASTAPI_REPO="https://github.com/100-hours-a-week/11-team-service-ai"

# 버전
export JDK_VERSION="21"
export NODE_VERSION="22"
export PYTHON_VERSION="3.11"
export NGINX_VERSION="1.28.1"

# =============================================
# 스크립트 경로
# =============================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${SCRIPT_DIR}/install"
CONFIG_DIR="${SCRIPT_DIR}/config"

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

# 설정 적용
source ${CONFIG_DIR}/nginx.sh

echo "=== 소스코드 및 개발 환경 설치 완료 ==="
