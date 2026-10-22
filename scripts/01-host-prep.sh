#!/usr/bin/env bash
# Host preparation: firewalld, local root CA, OS trust store, kubeseal CLI.
# Idempotent: safe to re-run.
source "$(dirname "$0")/lib.sh"

need openssl
need curl

# --- firewalld: let pod and service traffic through (k3s docs recommendation)
if systemctl is-active --quiet firewalld; then
  log "Adding k3s pod/service CIDRs to firewalld trusted zone"
  sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16 >/dev/null
  sudo firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16 >/dev/null
  sudo firewall-cmd --permanent --add-port=6443/tcp >/dev/null
  sudo firewall-cmd --permanent --add-port=80/tcp --add-port=443/tcp >/dev/null
  sudo firewall-cmd --reload >/dev/null
fi

# --- /etc/hosts: some routers drop 127.0.0.1 answers for *.localtest.me
# (DNS-rebinding protection), which breaks the browser and the apiserver's OIDC.
log "Pinning *.localtest.me hostnames to 127.0.0.1 in /etc/hosts"
sudo sed -i '/# k3s-gitops begin/,/# k3s-gitops end/d' /etc/hosts
sudo tee -a /etc/hosts >/dev/null <<'EOF'
# k3s-gitops begin
127.0.0.1 argocd.localtest.me keycloak.localtest.me headlamp.localtest.me nginx.localtest.me
# k3s-gitops end
EOF

# --- Root CA (never committed; key stays in ~/.k3s-gitops/ca)
mkdir -p "${CA_DIR}"
chmod 700 "${STATE_DIR}" "${CA_DIR}"
if [[ ! -f "${CA_DIR}/ca.key" ]]; then
  log "Generating platform root CA in ${CA_DIR}"
  openssl genrsa -out "${CA_DIR}/ca.key" 4096 2>/dev/null
  openssl req -x509 -new -nodes -key "${CA_DIR}/ca.key" -sha256 -days 3650 \
    -subj "/CN=k3s-gitops platform CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -out "${CA_DIR}/ca.crt"
  chmod 600 "${CA_DIR}/ca.key"
else
  log "Root CA already exists, keeping it"
fi

# --- Trust the CA on the host (curl, Go tools, Chrome via p11-kit)
log "Adding root CA to the system trust store"
sudo cp "${CA_DIR}/ca.crt" /etc/pki/ca-trust/source/anchors/k3s-gitops-ca.crt
sudo update-ca-trust

# --- kubeseal CLI
if ! command -v kubeseal >/dev/null 2>&1; then
  log "Installing kubeseal ${KUBESEAL_VERSION} to ~/.local/bin"
  mkdir -p "${HOME}/.local/bin"
  tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/kubeseal.tgz" \
    "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
  tar -xzf "${tmp}/kubeseal.tgz" -C "${tmp}" kubeseal
  install -m 0755 "${tmp}/kubeseal" "${HOME}/.local/bin/kubeseal"
  rm -rf "${tmp}"
fi

log "Host prep done"
