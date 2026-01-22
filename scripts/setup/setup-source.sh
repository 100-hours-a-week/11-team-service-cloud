#!/bin/bash

# 변수 설정 (수정 필요)
FRONTEND_REPO="https://github.com/100-hours-a-week/11-team-service-fe"
BACKEND_REPO="https://github.com/100-hours-a-week/11-team-service-be"
FASTAPI_REPO="https://github.com/100-hours-a-week/11-team-service-ai"

# JDK, Node, Python 버전
JDK_VERSION="21"
NODE_VERSION="22"
PYTHON_VERSION="3.11"

sleep 1 # 잠시 대기
echo "=== 패키지 업데이트 ==="
sudo add-apt-repository ppa:deadsnakes/ppa -y # Python 3.11 버전 설치를 위해 추가.
sudo apt update
sudo apt upgrade -y

sleep 1 # 잠시 대기
echo "=== Git 설치 ==="
sudo apt install git -y

sleep 3 # 잠시 대기
echo "=== 프로젝트 클론 ==="
cd /home/ubuntu
git clone ${FRONTEND_REPO} frontend
git clone ${BACKEND_REPO} backend
git clone ${FASTAPI_REPO} fastAPI

sleep 1 # 잠시 대기
echo "=== Nginx 설치 ==="
sudo apt install nginx -y
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
sudo cp ${SCRIPT_DIR}/config/nginx/default.conf /etc/nginx/sites-available/default.conf
sudo nginx -t && sudo systemctl restart nginx

sleep 1 # 잠시 대기
echo "=== Java 설치 ==="
sudo apt install openjdk-${JDK_VERSION}-jdk -y

sleep 1 # 잠시 대기
echo "=== unzip 설치 ==="
sudo apt install unzip -y

sleep 1 # 잠시 대기
echo "=== gradle 설치 ==="
wget https://services.gradle.org/distributions/gradle-8.14.3-bin.zip
sudo unzip gradle-8.14.3-bin.zip -d /opt/gradle
echo 'export PATH=/opt/gradle/gradle-8.14.3/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

sleep 1 # 잠시 대기
echo "=== Node.js 설치 ==="
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
sudo apt install nodejs -y

sleep 1 # 잠시 대기
echo "=== Python 설치 ==="
sudo apt install python${PYTHON_VERSION} python3-pip python3-venv -y

echo "=== 환경 세팅 완료 ==="