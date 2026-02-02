#!/bin/bash

# =============================================
# SSL 인증서 발급 스크립트 (Certbot + Nginx)
# =============================================

set -e

# .env 로드
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../../.."

if [ ! -f "${PROJECT_ROOT}/.env" ]; then
  echo "ERROR: .env 파일이 없습니다."
  exit 1
fi

set -a
source "${PROJECT_ROOT}/.env"
set +a

# 도메인 검증
if [ -z "$SERVICE_DOMAIN" ]; then
  echo "ERROR: SERVICE_DOMAIN이 .env에 설정되지 않았습니다."
  exit 1
fi

echo "=== SSL 인증서 발급 시작 ==="
echo "도메인: ${SERVICE_DOMAIN}, www.${SERVICE_DOMAIN}"

# Certbot 설치 확인
if ! command -v certbot &> /dev/null; then
  echo "=== Certbot 설치 ==="
  sudo apt update
  sudo apt install -y certbot python3-certbot-nginx
fi

# 인증서 발급 + Nginx 자동 설정
echo "=== Certbot으로 인증서 발급 및 Nginx 설정 ==="
sudo certbot --nginx \
  -d ${SERVICE_DOMAIN} -d www.${SERVICE_DOMAIN} \
  --non-interactive --agree-tos --email ${CERTBOT_EMAIL:-admin@${SERVICE_DOMAIN}}

# 자동 갱신 테스트
echo "=== 인증서 자동 갱신 테스트 ==="
sudo certbot renew --dry-run

echo "=== SSL 설정 완료 ==="
echo "https://${SERVICE_DOMAIN} 으로 접속 가능합니다."