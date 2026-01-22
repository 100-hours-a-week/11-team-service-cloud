#!/bin/bash

# 변수 설정 (수정 필요)
DB_SCHEMA="service_db"
DB_PASSWORD="Qwerty123456!"

sleep 1 # 잠시 대기
echo "=== 패키지 업데이트 ==="
sudo apt update
sudo apt upgrade -y

sleep 1 # 잠시 대기
echo "=== MySQL 설치 및 실행 ==="
sudo apt install mysql-server -y
sudo systemctl enable mysql
sudo systemctl start mysql

echo "=== MySQL 초기 세팅 ==="
sleep 10  # MySQL 서버 완전 시작 대기

sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
FLUSH PRIVILEGES;
CREATE DATABASE ${DB_SCHEMA};
EOF

sleep 1 # 잠시 대기
echo "=== 환경 변수 파일 작성 ==="
cd /home/ubuntu
cat << EOF > .env
export DB_HOST=localhost
export DB_PORT=3306
export DB_NAME=${DB_SCHEMA}
export DB_PASSWORD=${DB_PASSWORD}
EOF

echo "=== 환경 변수 적용 ==="
set -a
source .env
set +a

echo "=== 환경 세팅 완료 ==="