#!/bin/bash

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
cat << EOF | sudo tee "$SERVER_ENV_PATH" >/dev/null
export DB_HOST=localhost
export DB_PORT=3306
export DB_SCHEMA=${DB_SCHEMA}
export DB_USER=${DB_USER}
export DB_PASSWORD=${DB_PASSWORD}
EOF

sudo chmod 600 "$SERVER_ENV_PATH"
sudo chown ubuntu:ubuntu "$SERVER_ENV_PATH"

set -a
source "$SERVER_ENV_PATH"
set +a
