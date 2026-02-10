#!/bin/bash

# =============================================
# .env 로드
# =============================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."

if [ ! -f "${PROJECT_ROOT}/.env" ]; then
  echo "ERROR: .env 파일이 없습니다. .env.example을 참고하여 .env를 생성해주세요."
  exit 1
fi

set -a
source "${PROJECT_ROOT}/.env"
set +a

# =============================================
# 경로 설정
# =============================================
BACKEND_DIR="/home/ubuntu/backend"
BACKEND_RELEASE_DIR="${BACKEND_DIR}/release/latest"

# =============================================
# 함수
# =============================================

# S3에서 백엔드 JAR 다운로드 (파일명 같으면 스킵)
download_backend() {
    echo "=== 백엔드 JAR 다운로드 ==="

    # release 디렉토리 생성
    mkdir -p "${BACKEND_RELEASE_DIR}"

    # S3에서 latest JAR 파일명 조회
    S3_JAR_NAME=$(aws s3 ls "s3://${S3_BUCKET}/${S3_BACKEND_PREFIX}/latest/" | grep '\.jar$' | awk '{print $4}')

    if [ -z "$S3_JAR_NAME" ]; then
        echo "ERROR: S3에서 JAR 파일을 찾을 수 없습니다."
        return 1
    fi

    LOCAL_JAR_PATH="${BACKEND_RELEASE_DIR}/${S3_JAR_NAME}"

    # 로컬에 같은 파일이 있는지 확인
    if [ -f "$LOCAL_JAR_PATH" ]; then
        echo "이미 동일한 파일이 존재합니다: ${S3_JAR_NAME} (스킵)"
    else
        # 기존 JAR 파일 삭제 후 새로 다운로드
        rm -f "${BACKEND_RELEASE_DIR}"/*.jar
        echo "다운로드 중: ${S3_JAR_NAME}"
        aws s3 cp "s3://${S3_BUCKET}/${S3_BACKEND_PREFIX}/latest/${S3_JAR_NAME}" "${LOCAL_JAR_PATH}"
        echo "다운로드 완료: ${LOCAL_JAR_PATH}"
    fi

    # 현재 JAR 파일명 저장 (start에서 사용)
    BACKEND_JAR="${S3_JAR_NAME}"
}

start() {
    echo "=== 프론트엔드 실행 ==="
    cd /home/ubuntu/frontend
    nohup npx serve build -l 3000 > frontend.log 2>&1 &
    sleep 2
    ps aux | grep serve | grep -v grep

    echo "=== 백엔드 실행 ==="
    # release/latest에서 JAR 찾아서 실행
    BACKEND_JAR=$(ls "${BACKEND_RELEASE_DIR}"/*.jar 2>/dev/null | head -1)
    if [ -z "$BACKEND_JAR" ]; then
        echo "ERROR: 백엔드 JAR 파일이 없습니다. 먼저 download를 실행하세요."
        return 1
    fi
    cd "${BACKEND_DIR}"
    nohup java -jar "${BACKEND_JAR}" > backend.log 2>&1 &
    sleep 2
    ps aux | grep java | grep -v grep

    echo "=== FastAPI 실행 ==="
    cd /home/ubuntu/ai
    nohup uv run uvicorn api.main:app --host 0.0.0.0 --port 8000 > ai.log 2>&1 &
    echo $! > uvicorn.pid
    sleep 2
    ps aux | grep uvicorn | grep -v grep

    echo "=== 실행 완료 ==="
}

stop() {
    echo "=== 프론트엔드 종료 ==="
    pkill -f "serve build"

    echo "=== 백엔드 종료 ==="
    pkill -f "java -jar"

    echo "=== FastAPI 종료 ==="
    if [ -f /home/ubuntu/ai/uvicorn.pid ]; then
      kill "$(cat /home/ubuntu/ai/uvicorn.pid)" 2>/dev/null || true
      rm -f /home/ubuntu/ai/uvicorn.pid
    fi

    echo "=== 종료 완료 ==="
}

restart() {
    stop
    sleep 3
    start
}

# 다운로드 + 재시작
deploy() {
    download_backend
    restart
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    download)
        download_backend
        ;;
    deploy)
        deploy
        ;;
    *)
        echo "사용법: $0 {start|stop|restart|download|deploy}"
        exit 1
        ;;
esac
