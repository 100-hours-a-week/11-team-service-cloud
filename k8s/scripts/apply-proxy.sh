#!/bin/bash
# ArgoCD Egress Proxy 설정 — 마스터 노드에서 실행
PROXY_URL="http://10.4.0.149:3128"
NO_PROXY="10.0.0.0/8,192.168.0.0/16,10.96.0.0/12,172.16.0.0/12,127.0.0.1,localhost,.cluster.local,.svc,169.254.169.254"

for DEPLOY in argocd-server argocd-repo-server argocd-application-controller argocd-image-updater-controller; do
  kubectl set env deployment/${DEPLOY} -n argocd \
    HTTP_PROXY="${PROXY_URL}" \
    HTTPS_PROXY="${PROXY_URL}" \
    NO_PROXY="${NO_PROXY}"
done

echo "프록시 설정 완료. Pod 상태:"
kubectl get pods -n argocd
