#!/bin/bash

# 변수 설정 (수정 필요)
DB_SCHEMA="service_db"
DB_USER="developer"
DB_PASSWORD="Qwerty123456!"
ENV_PATH="/home/ubuntu/.env"
MYSQL_VERSION="8.0.44"

sleep 1 # 잠시 대기
echo "=== 패키지 업데이트 ==="
sudo apt update

sleep 1 # 잠시 대기
echo "=== MySQL APT 저장소 추가 ==="
wget -q https://dev.mysql.com/get/mysql-apt-config_0.8.33-1_all.deb
echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.33-1_all.deb
rm -f mysql-apt-config_0.8.33-1_all.deb
sudo apt update

sleep 1 # 잠시 대기
echo "=== MySQL ${MYSQL_VERSION} 설치 및 실행 ==="
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  mysql-community-server=${MYSQL_VERSION}-1ubuntu$(lsb_release -rs) \
  mysql-community-client=${MYSQL_VERSION}-1ubuntu$(lsb_release -rs)
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
export DB_SCHEMA=${DB_SCHEMA}
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