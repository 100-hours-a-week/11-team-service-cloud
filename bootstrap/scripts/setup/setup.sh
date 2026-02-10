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

echo "=== 프로젝트 디렉토리 생성 ==="
mkdir -p /home/ubuntu/frontend
mkdir -p /home/ubuntu/backend
mkdir -p /home/ubuntu/ai
chown -R ubuntu:ubuntu /home/ubuntu/frontend /home/ubuntu/backend /home/ubuntu/ai

# 개별 설치 스크립트 실행
source ${INSTALL_DIR}/nginx.sh
source ${INSTALL_DIR}/java.sh
source ${INSTALL_DIR}/node.sh
source ${INSTALL_DIR}/python.sh
source ${INSTALL_DIR}/mysql.sh
source ${INSTALL_DIR}/aws-cli.sh

# 설정 적용
source ${CONFIG_DIR}/nginx.sh
source ${CONFIG_DIR}/mysql.sh

echo "=== 전체 환경 세팅 완료 ==="
