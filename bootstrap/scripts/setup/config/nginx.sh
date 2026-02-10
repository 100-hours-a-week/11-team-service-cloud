#!/bin/bash

CONFIG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${CONFIG_SCRIPT_DIR}/../../.."

echo "=== Nginx 설정 적용 ==="
# 도메인 치환 후 복사
sudo sed "s/service_domain/${SERVICE_DOMAIN}/g" ${PROJECT_ROOT}/configs/nginx/default.conf > /tmp/default.conf
sudo mv /tmp/default.conf /etc/nginx/conf.d/default.conf
sudo nginx -t && sudo systemctl restart nginx
