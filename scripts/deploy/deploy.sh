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
# 함수
# =============================================
start() {
    echo "=== 프론트엔드 실행 ==="
    cd /home/ubuntu/frontend
    nohup npx serve build -l 3000 > frontend.log 2>&1 &
    sleep 2
    ps aux | grep serve | grep -v grep

    echo "=== 백엔드 실행 ==="
    cd /home/ubuntu/backend
    nohup java -jar build/libs/${BACKEND_JAR} > backend.log 2>&1 &
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
    *)
        echo "사용법: $0 {start|stop|restart}"
        exit 1
        ;;
esac
