#!/bin/bash

# =============================================
# 변수 설정 (수정 필요)
# =============================================
export DB_SCHEMA="service_db"
export DB_USER="developer"
export DB_PASSWORD="Qwerty123456!"
export ENV_PATH="/home/ubuntu/.env"
export MYSQL_VERSION="8.0.44"

# =============================================
# 스크립트 경로
# =============================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${SCRIPT_DIR}/install"

# =============================================
# 실행
# =============================================
echo "=== 패키지 업데이트 ==="
sudo apt update

source ${INSTALL_DIR}/mysql.sh

echo "=== MySQL 설치 및 설정 완료 ==="
