#!/bin/bash

# 변수 설정 (수정 필요)
DB_SCHEMA="service_db"
DB_USER="developer"
DB_PASSWORD="Qwerty123456!"
ENV_PATH="/home/ubuntu/.env"

sleep 1 # 잠시 대기
echo "=== 패키지 업데이트 ==="
sudo apt update

sleep 1 # 잠시 대기
echo "=== MySQL 설치 및 실행 ==="
sudo apt install mysql-server -y
sudo systemctl enable mysql
sudo systemctl start mysql

echo "=== MySQL 초기 세팅 ==="
sleep 10  # MySQL 서버 완전 시작 대기

echo "=== DB/유저 생성(멱등성 고려) ==="
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_SCHEMA}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${DB_SCHEMA}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

sleep 1 # 잠시 대기
echo "=== 환경 변수 파일 작성 ==="
cat << EOF | sudo tee "$ENV_PATH" >/dev/null
export DB_HOST=localhost
export DB_PORT=3306
export DB_NAME=${DB_SCHEMA}
export DB_USER=${DB_USER}
export DB_PASSWORD=${DB_PASSWORD}
EOF

sudo chmod 600 "$ENV_PATH"
sudo chown ubuntu:ubuntu "$ENV_PATH"

echo "=== 환경 변수 적용 ==="
set -a
source "$ENV_PATH"
set +a

echo "=== 환경 세팅 완료 ==="