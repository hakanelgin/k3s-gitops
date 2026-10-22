#!/usr/bin/env bash
# Installs a pinned single-node k3s with apiserver OIDC enabled.
source "$(dirname "$0")/lib.sh"

need curl
[[ -f "${CA_DIR}/ca.crt" ]] || die "Root CA missing, run 01-host-prep.sh first"

log "Writing /etc/rancher/k3s/config.yaml and OIDC CA"
sudo mkdir -p /etc/rancher/k3s
sudo install -m 0644 "${REPO_ROOT}/k3s/config.yaml" /etc/rancher/k3s/config.yaml
sudo install -m 0644 "${REPO_ROOT}/k3s/resolv.conf" /etc/rancher/k3s/resolv.conf
sudo install -m 0644 "${CA_DIR}/ca.crt" /etc/rancher/k3s/platform-ca.crt

log "Installing k3s ${K3S_VERSION}"
curl -sfL https://get.k3s.io | sudo INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - server

log "Writing kubeconfig to ${KUBECONFIG}"
mkdir -p "$(dirname "${KUBECONFIG}")"
sudo cat /etc/rancher/k3s/k3s.yaml > "${KUBECONFIG}"
chmod 600 "${KUBECONFIG}"

log "Waiting for the node to become Ready"
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl get nodes -o wide

log "k3s installed. Use: export KUBECONFIG=${KUBECONFIG}"
