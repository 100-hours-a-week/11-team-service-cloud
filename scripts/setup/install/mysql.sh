#!/bin/bash

echo "=== MySQL APT 저장소 추가 ==="
wget -q https://dev.mysql.com/get/mysql-apt-config_0.8.33-1_all.deb
echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.33-1_all.deb
rm -f mysql-apt-config_0.8.33-1_all.deb
sudo apt update

echo "=== MySQL ${MYSQL_VERSION} 설치 ==="
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  mysql-community-server=${MYSQL_VERSION}-1ubuntu$(lsb_release -rs) \
  mysql-community-client=${MYSQL_VERSION}-1ubuntu$(lsb_release -rs)
sudo systemctl enable mysql
sudo systemctl start mysql

echo "=== MySQL 초기 세팅 ==="
sleep 10

echo "=== DB/유저 생성 ==="
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_SCHEMA}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_SCHEMA}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

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

set -a
source "$ENV_PATH"
set +a
