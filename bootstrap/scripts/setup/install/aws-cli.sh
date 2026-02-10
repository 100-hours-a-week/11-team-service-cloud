#!/bin/bash

# Exit on any error
set -e

echo "=== AWS CLI v2 설치 시작 ==="

# 1. AWS CLI가 이미 설치되어 있는지 확인
if command -v aws &> /dev/null; then
    echo "AWS CLI가 이미 설치되어 있습니다."
    aws --version
    echo "설치를 건너뜁니다."
    # setup.sh에서 source로 실행될 것을 고려하여 exit 0 대신 return 0 사용
    return 0
fi

# 2. 의존성 패키지 설치
echo "의존성 패키지(curl, unzip)를 설치합니다..."
sudo apt-get update
sudo apt-get install -y curl unzip

# 3. AWS CLI 다운로드 및 설치
echo "AWS CLI v2를 다운로드합니다..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

echo "설치 파일의 압축을 해제합니다..."
unzip awscliv2.zip

echo "설치를 실행합니다..."
# /usr/local/aws-cli 에 설치하고 /usr/local/bin/aws 에 심볼릭 링크 생성
sudo ./aws/install

# 4. 설치 파일 정리
echo "설치 파일을 정리합니다..."
rm -f awscliv2.zip
rm -rf ./aws

# 5. 설치 확인
echo "AWS CLI 설치를 확인합니다..."
if command -v aws &> /dev/null; then
    echo "AWS CLI가 성공적으로 설치되었습니다."
    aws --version
else
    echo "오류: AWS CLI 설치에 실패했습니다."
    exit 1
fi

echo "=== AWS CLI v2 설치 완료 ==="
