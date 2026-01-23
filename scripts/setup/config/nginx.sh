#!/bin/bash

CONFIG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${CONFIG_SCRIPT_DIR}/../../.."

echo "=== Nginx 설정 적용 ==="
sudo cp ${PROJECT_ROOT}/configs/nginx/default.conf /etc/nginx/conf.d/default.conf
sudo nginx -t && sudo systemctl restart nginx
