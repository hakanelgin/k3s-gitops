#!/usr/bin/env bash
# One-time bootstrap: CA secret, ArgoCD via Helm, root app-of-apps.
# After this, ArgoCD manages everything (including itself) from Git.
source "$(dirname "$0")/lib.sh"

need kubectl
need helm
[[ -f "${CA_DIR}/ca.key" ]] || die "Root CA missing, run 01-host-prep.sh first"

log "Creating namespaces argocd and cert-manager"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

# The CA key is the one secret that is never in Git (not even sealed):
# it's needed before Sealed Secrets exists.
log "Loading root CA into cert-manager/platform-root-ca"
kubectl -n cert-manager create secret tls platform-root-ca \
  --cert="${CA_DIR}/ca.crt" --key="${CA_DIR}/ca.key" \
  --dry-run=client -o yaml | kubectl apply -f -

log "Installing ArgoCD chart ${ARGOCD_CHART_VERSION}"
helm repo add argo https://argoproj.github.io/argo-helm --force-update >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --version "${ARGOCD_CHART_VERSION}" \
  --namespace argocd \
  --values "${REPO_ROOT}/platform/argocd/values.yaml" \
  --wait --timeout 10m

log "Applying root application"
kubectl apply -f "${REPO_ROOT}/bootstrap/root-app.yaml"

log "Bootstrap done. Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
