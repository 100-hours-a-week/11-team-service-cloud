#!/bin/bash
set -euo pipefail

# =============================================================================
# 로컬 Multipass 클러스터 셋업 스크립트
# 마스터 노드에서 실행
#
# 사전 조건:
#   - K8s 클러스터 구성 완료 (kubeadm + calico)
#   - 마스터 노드에 aws cli 설치 완료
#   - aws configure 완료 (ECR 접근 가능한 IAM 사용자)
#
# 사용법:
#   ./setup-local.sh
# =============================================================================

ECR_REGISTRY="209192769586.dkr.ecr.ap-northeast-2.amazonaws.com"
NAMESPACE="dev"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================================"
echo " 로컬 클러스터 셋업"
echo "================================================"

# -----------------------------------------------------------------------------
# 0. 사전 조건 확인
# -----------------------------------------------------------------------------
echo ""
echo "[0/3] 사전 조건 확인..."

if ! command -v kubectl &> /dev/null; then
  echo "ERROR: kubectl이 설치되어 있지 않습니다."
  exit 1
fi

if ! command -v aws &> /dev/null; then
  echo "ERROR: aws cli가 설치되어 있지 않습니다."
  exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
  echo "ERROR: K8s 클러스터에 연결할 수 없습니다."
  exit 1
fi

echo "kubectl: OK"
echo "aws cli: OK"
echo "cluster: OK"

# -----------------------------------------------------------------------------
# 1. 네임스페이스 생성
# -----------------------------------------------------------------------------
echo ""
echo "[1/3] 네임스페이스 생성..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# -----------------------------------------------------------------------------
# 2. ECR imagePullSecret 생성
# -----------------------------------------------------------------------------
echo ""
echo "[2/3] ECR imagePullSecret 생성..."

ECR_TOKEN=$(aws ecr get-login-password --region ap-northeast-2)

kubectl create secret docker-registry ecr-secret \
  -n ${NAMESPACE} \
  --docker-server=${ECR_REGISTRY} \
  --docker-username=AWS \
  --docker-password="${ECR_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "ecr-secret 시크릿 생성 완료"
echo "※ ECR 토큰은 12시간 후 만료됩니다. 만료 시 이 스크립트를 다시 실행하세요."

# -----------------------------------------------------------------------------
# 3. 앱 배포 (local overlay 사용)
# -----------------------------------------------------------------------------
echo ""
echo "[3/3] 앱 배포..."
kubectl apply -k "${MANIFEST_DIR}/apps/frontend/overlays/local"
kubectl apply -k "${MANIFEST_DIR}/apps/backend/overlays/local"
kubectl apply -k "${MANIFEST_DIR}/apps/ai/overlays/local"

echo ""
echo "================================================"
echo " 셋업 완료"
echo "================================================"
echo ""
echo "Pod 상태 확인:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "서비스 확인:"
echo "  kubectl get svc -n ${NAMESPACE}"
echo ""
