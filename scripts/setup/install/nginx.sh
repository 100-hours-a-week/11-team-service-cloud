#!/bin/bash

echo "=== Nginx APT 저장소 추가 ==="
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" \
  | sudo tee /etc/apt/sources.list.d/nginx.list
sudo apt update

echo "=== Nginx ${NGINX_VERSION} 설치 ==="
sudo apt install -y nginx=${NGINX_VERSION}-1~$(lsb_release -cs)
sudo systemctl enable nginx
