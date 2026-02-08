#!/bin/bash

# Usage:
#   ./run-test.sh <base-url> <test-type> [--no-dashboard]
#
# Examples:
#   ./run-test.sh http://127.0.0.1:8080 quick
#   ./run-test.sh http://127.0.0.1:8080 job-analysis
#   ./run-test.sh http://127.0.0.1:8080 application-eval
#   ./run-test.sh http://127.0.0.1:8080 chat
#
# Env:
#   ACCESS_TOKEN=... or REFRESH_TOKEN=...
#   VUS=10 DURATION=30s THINK_TIME_MS=200

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
RESULTS_DIR="$SCRIPT_DIR/results"

mkdir -p "$RESULTS_DIR"

BASE_URL="${1:-}"
TEST_TYPE="${2:-quick}"
NO_DASHBOARD="${3:-}"

if [[ -z "$BASE_URL" ]]; then
  echo "base-url is required (e.g. http://127.0.0.1:8080)" >&2
  exit 1
fi

K6_SCRIPT=""
case "$TEST_TYPE" in
  quick) K6_SCRIPT="$SCRIPTS_DIR/quick.js";;
  job-analysis) K6_SCRIPT="$SCRIPTS_DIR/job-analysis.js";;
  application-eval) K6_SCRIPT="$SCRIPTS_DIR/application-eval.js";;
  chat) K6_SCRIPT="$SCRIPTS_DIR/chat-load.js";;
  *)
    echo "Unknown test-type: $TEST_TYPE" >&2
    echo "Supported: quick | job-analysis | application-eval | chat" >&2
    exit 1
    ;;
esac

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="$RESULTS_DIR/${TEST_TYPE}-${TS}.json"

echo "[k6] base-url: $BASE_URL"
echo "[k6] script:   $K6_SCRIPT"
echo "[k6] output:   $OUT_JSON"

DASHBOARD_OUT=""
if [[ "$NO_DASHBOARD" != "--no-dashboard" ]]; then
  DASHBOARD_OUT="--out dashboard"
fi

# VAR=value command args...: commmand에 VAR 환경변수를 설정하여 실행
TARGET_BASE_URL="$BASE_URL" k6 run \
  --out "json=$OUT_JSON" \
  --out "prometheus-rw" \
  $DASHBOARD_OUT \
  "$K6_SCRIPT"
