#!/usr/bin/env bash
# Generates random OIDC client secrets and demo-user passwords, seals them
# with the cluster's Sealed Secrets key and writes the SealedSecrets into the repo.
# Plain values are kept only in ~/.k3s-gitops/credentials.env (mode 600).
#
# Usage: 04-seal-secrets.sh [--rotate]
source "$(dirname "$0")/lib.sh"

need kubectl
need kubeseal
need openssl

CREDS="${STATE_DIR}/credentials.env"
SEAL=(kubeseal --format yaml --controller-namespace kube-system --controller-name sealed-secrets-controller)

log "Waiting for the Sealed Secrets controller"
kubectl -n kube-system rollout status deploy/sealed-secrets-controller --timeout=300s

if [[ ! -f "${CREDS}" || "${1:-}" == "--rotate" ]]; then
  log "Generating new credentials in ${CREDS}"
  rand() { openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32; }
  umask 077
  cat > "${CREDS}" <<EOF
ARGOCD_CLIENT_SECRET=$(rand)
HEADLAMP_CLIENT_SECRET=$(rand)
DEMO_ADMIN_PASSWORD=$(rand)
DEMO_VIEWER_PASSWORD=$(rand)
EOF
fi
# shellcheck disable=SC1090
source "${CREDS}"

log "Sealing keycloak/realm-secrets"
"${SEAL[@]}" > "${REPO_ROOT}/platform/keycloak/realm-secrets.sealed.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: realm-secrets
  namespace: keycloak
stringData:
  ARGOCD_CLIENT_SECRET: "${ARGOCD_CLIENT_SECRET}"
  HEADLAMP_CLIENT_SECRET: "${HEADLAMP_CLIENT_SECRET}"
  DEMO_ADMIN_PASSWORD: "${DEMO_ADMIN_PASSWORD}"
  DEMO_VIEWER_PASSWORD: "${DEMO_VIEWER_PASSWORD}"
EOF

log "Sealing argocd/argocd-oidc"
"${SEAL[@]}" > "${REPO_ROOT}/platform/argocd/manifests/argocd-oidc.sealed.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: argocd-oidc
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: argocd
stringData:
  clientSecret: "${ARGOCD_CLIENT_SECRET}"
EOF

log "Sealing headlamp/headlamp-oidc"
"${SEAL[@]}" > "${REPO_ROOT}/platform/headlamp/manifests/headlamp-oidc.sealed.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: headlamp-oidc
  namespace: headlamp
stringData:
  OIDC_CLIENT_ID: headlamp
  OIDC_CLIENT_SECRET: "${HEADLAMP_CLIENT_SECRET}"
  OIDC_ISSUER_URL: https://keycloak.localtest.me/realms/platform
  OIDC_SCOPES: "openid,profile,email"
EOF

# Without this key a rebuilt cluster cannot decrypt the sealed files in Git.
log "Exporting Sealed Secrets master key to ${STATE_DIR}/sealed-secrets-key.yaml"
umask 077
kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml \
  > "${STATE_DIR}/sealed-secrets-key.yaml"

log "Done. Commit and push the *.sealed.yaml files. Demo logins:"
echo "  demo-admin  / ${DEMO_ADMIN_PASSWORD}"
echo "  demo-viewer / ${DEMO_VIEWER_PASSWORD}"
