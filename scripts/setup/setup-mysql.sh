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
sudo apt update

source ${INSTALL_DIR}/mysql.sh
source ${CONFIG_DIR}/mysql.sh

echo "=== MySQL 설치 및 설정 완료 ==="
