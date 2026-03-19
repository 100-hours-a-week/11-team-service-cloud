#!/bin/bash
set -euo pipefail

# =============================================================================
# ArgoCD + Image Updater v1.x + External Secrets Operator 셋업 스크립트
# 사용법: ./setup-argocd.sh [--github-pat <PAT>] [--proxy <PROXY_IP>]
#
# 사전 조건:
#   - K8s 클러스터 구성 완료
#   - helm 설치 완료
#   - kubectl 접근 가능
# =============================================================================

ARGOCD_VERSION="v3.3.4"
IMAGE_UPDATER_VERSION="stable"
ECR_REGISTRY="209192769586.dkr.ecr.ap-northeast-2.amazonaws.com"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
MANIFEST_DIR="$(dirname "$SCRIPT_DIR")"

# Egress Proxy (Squid) — NAT Gateway 없는 Private Subnet 환경에서 필요
EGRESS_PROXY_HOST="${EGRESS_PROXY_HOST:-}"
EGRESS_PROXY_PORT="${EGRESS_PROXY_PORT:-3128}"
NO_PROXY="10.0.0.0/8,192.168.0.0/16,10.96.0.0/12,172.16.0.0/12,127.0.0.1,localhost,.cluster.local,.svc,169.254.169.254"

# 인자 파싱
GITHUB_PAT=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --github-pat) GITHUB_PAT="$2"; shift 2 ;;
    --proxy) EGRESS_PROXY_HOST="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo "================================================"
echo " ArgoCD + Image Updater + ESO Setup"
echo "================================================"

# -----------------------------------------------------------------------------
# 0. Helm 확인
# -----------------------------------------------------------------------------
echo ""
echo "[0/8] 사전 조건 확인..."
if ! command -v helm &> /dev/null; then
  echo "ERROR: helm이 설치되어 있지 않습니다."
  echo "  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
  exit 1
fi
echo "helm: OK"

# -----------------------------------------------------------------------------
# 1. ArgoCD 설치
# -----------------------------------------------------------------------------
echo ""
echo "[1/8] ArgoCD ${ARGOCD_VERSION} 설치..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "ArgoCD Pod 대기 중..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

echo ""
echo "ArgoCD admin 초기 비밀번호:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""

# -----------------------------------------------------------------------------
# 1.5 Egress Proxy 설정 (NAT Gateway 없는 환경)
# -----------------------------------------------------------------------------
if [ -n "$EGRESS_PROXY_HOST" ]; then
  echo "[1.5/9] Egress Proxy 설정 (${EGRESS_PROXY_HOST}:${EGRESS_PROXY_PORT})..."
  PROXY_URL="http://${EGRESS_PROXY_HOST}:${EGRESS_PROXY_PORT}"

  for DEPLOY in argocd-server argocd-repo-server argocd-application-controller; do
    kubectl set env deployment/${DEPLOY} -n argocd \
      HTTP_PROXY="${PROXY_URL}" \
      HTTPS_PROXY="${PROXY_URL}" \
      NO_PROXY="${NO_PROXY}"
  done

  echo "ArgoCD 프록시 설정 완료. Pod 재시작 대기 중..."
  kubectl rollout status deployment/argocd-server -n argocd --timeout=120s
else
  echo "[1.5/9] [SKIP] --proxy 미지정. NAT Gateway가 있는 환경이면 불필요."
fi

# -----------------------------------------------------------------------------
# 2. ArgoCD Image Updater v1.x 설치 (CRD 포함)
# -----------------------------------------------------------------------------
echo "[2/8] ArgoCD Image Updater ${IMAGE_UPDATER_VERSION} 설치..."
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/${IMAGE_UPDATER_VERSION}/config/install.yaml"

echo "Image Updater Pod 대기 중..."
kubectl wait --for=condition=available deployment/argocd-image-updater-controller -n argocd --timeout=120s

if [ -n "$EGRESS_PROXY_HOST" ]; then
  echo "Image Updater 프록시 설정..."
  kubectl set env deployment/argocd-image-updater-controller -n argocd \
    HTTP_PROXY="http://${EGRESS_PROXY_HOST}:${EGRESS_PROXY_PORT}" \
    HTTPS_PROXY="http://${EGRESS_PROXY_HOST}:${EGRESS_PROXY_PORT}" \
    NO_PROXY="${NO_PROXY}"
fi

# -----------------------------------------------------------------------------
# 3. Image Updater 레지스트리 설정
# -----------------------------------------------------------------------------
echo "[3/8] ECR 레지스트리 설정 적용..."
kubectl apply -f "${MANIFEST_DIR}/argocd/image-updater/registries.yaml"
kubectl rollout restart deployment/argocd-image-updater-controller -n argocd

# -----------------------------------------------------------------------------
# 4. Git write-back 시크릿 설정
# -----------------------------------------------------------------------------
echo "[4/8] Git write-back 시크릿 설정..."

if [ -n "$GITHUB_PAT" ]; then
  kubectl create secret generic argocd-image-updater-git-secret \
    -n argocd \
    --from-literal=username=argocd-image-updater \
    --from-literal=password="${GITHUB_PAT}" \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "Git 시크릿 생성 완료"
else
  echo "[SKIP] --github-pat 미지정. 수동으로 생성 필요:"
  echo "  kubectl create secret generic argocd-image-updater-git-secret \\"
  echo "    -n argocd \\"
  echo "    --from-literal=username=argocd-image-updater \\"
  echo "    --from-literal=password=<YOUR_GITHUB_PAT>"
fi

# -----------------------------------------------------------------------------
# 5. ECR 토큰 갱신 CronJob 설정
# -----------------------------------------------------------------------------
echo ""
echo "[5/8] ECR 토큰 갱신 CronJob 설정..."
kubectl apply -f "${MANIFEST_DIR}/argocd/image-updater/ecr-token-cronjob.yaml"

echo "ECR 토큰 초기 생성 중..."
if command -v aws &> /dev/null; then
  TOKEN=$(aws ecr get-login-password --region ap-northeast-2 2>/dev/null || echo "")
  if [ -n "$TOKEN" ]; then
    kubectl create secret docker-registry ecr-secret \
      -n argocd \
      --docker-server="${ECR_REGISTRY}" \
      --docker-username=AWS \
      --docker-password="${TOKEN}" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "ECR 토큰 생성 완료"
  else
    echo "[SKIP] AWS CLI 인증 실패."
  fi
else
  echo "[SKIP] aws CLI 미설치."
fi

# -----------------------------------------------------------------------------
# 6. 네임스페이스 생성
# -----------------------------------------------------------------------------
echo ""
echo "[6/8] 애플리케이션 네임스페이스 생성..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

# -----------------------------------------------------------------------------
# 7. External Secrets Operator 설치 + ExternalSecret 등록
# -----------------------------------------------------------------------------
echo ""
echo "[7/8] External Secrets Operator 설치..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace --wait

echo "ClusterSecretStore + ExternalSecret 등록..."
kubectl apply -f "${MANIFEST_DIR}/external-secrets/cluster-secret-store.yaml"
kubectl apply -k "${MANIFEST_DIR}/external-secrets/dev"

# -----------------------------------------------------------------------------
# 8. ArgoCD Application + ImageUpdater CRD 등록
# -----------------------------------------------------------------------------
echo ""
echo "[8/8] ArgoCD Application + ImageUpdater CRD 등록..."

# Application 등록
kubectl apply -f "${MANIFEST_DIR}/argocd/frontend-dev-app.yaml"
kubectl apply -f "${MANIFEST_DIR}/argocd/backend-dev-app.yaml"
kubectl apply -f "${MANIFEST_DIR}/argocd/ai-dev-app.yaml"

# ImageUpdater CRD 등록 (ECR 태그 감시)
kubectl apply -f "${MANIFEST_DIR}/argocd/image-updater/frontend-dev-updater.yaml"
kubectl apply -f "${MANIFEST_DIR}/argocd/image-updater/backend-dev-updater.yaml"
kubectl apply -f "${MANIFEST_DIR}/argocd/image-updater/ai-dev-updater.yaml"

echo "Application + ImageUpdater 등록 완료"

# -----------------------------------------------------------------------------
# 완료
# -----------------------------------------------------------------------------
echo ""
echo "================================================"
echo " Setup 완료"
echo "================================================"
echo ""
echo "ArgoCD UI 접근 (포트포워딩):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo "  브라우저: https://localhost:8443"
echo "  ID: admin / PW: 위에 출력된 초기 비밀번호"
echo ""
echo "Image Updater 동작 확인:"
echo "  kubectl logs -n argocd deployment/argocd-image-updater-controller -f"
echo ""
echo "ImageUpdater CRD 상태 확인:"
echo "  kubectl get imageupdaters -n argocd"
echo ""
echo "롤백 방법:"
echo "  argocd app rollback <app-name> <revision>"
echo "  또는 ArgoCD UI → History and Rollback"
echo ""
