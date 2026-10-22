# Shared settings for all scripts. Source it, don't execute it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_URL="https://github.com/hakanelgin/k3s-gitops.git"

K3S_VERSION="v1.35.9+k3s1"
ARGOCD_CHART_VERSION="10.10.5"
KUBESEAL_VERSION="0.40.0"

# Everything sensitive lives here, outside the Git repo.
STATE_DIR="${HOME}/.k3s-gitops"
CA_DIR="${STATE_DIR}/ca"

# Separate kubeconfig so an existing ~/.kube/config is never touched.
export KUBECONFIG="${HOME}/.kube/k3s-gitops.yaml"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed"; }
