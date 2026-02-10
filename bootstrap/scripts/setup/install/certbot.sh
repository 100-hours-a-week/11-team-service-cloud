#!/bin/bash

if command -v certbot &> /dev/null; then
  echo "=== Certbot 이미 설치됨 (스킵) ==="
  return 0
fi

echo "=== Certbot 설치 ==="
sudo apt install -y certbot python3-certbot-nginx
