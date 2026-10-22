# k3s-gitops

Single-node k3s managed with GitOps by Argo CD (app-of-apps).

| Component | Purpose |
|---|---|
| Argo CD | GitOps engine, manages itself and everything in `apps/` |
| cert-manager + trust-manager | Certificates from a local root CA, CA bundle for pods |
| Sealed Secrets | Encrypted secrets, safe in this public repo |
| CloudNativePG | PostgreSQL for Keycloak |
| Keycloak Operator + Keycloak | SSO (realm `platform`) |
| Headlamp | Kubernetes UI with OIDC login |

## Endpoints

| URL | Login |
|---|---|
| https://argocd.localtest.me | Keycloak SSO (or `admin` break-glass) |
| https://keycloak.localtest.me | Keycloak admin: secret `keycloak/keycloak-initial-admin` |
| https://headlamp.localtest.me | Keycloak SSO, Kubernetes RBAC via apiserver OIDC |

Demo users (realm `platform`): `demo-admin` (group `platform-admins`) and
`demo-viewer` (group `viewers`). Passwords: `~/.k3s-gitops/credentials.env`.

## Quick start

See [docs/bootstrap.md](docs/bootstrap.md).

```bash
./scripts/01-host-prep.sh        # firewalld, root CA, trust store, kubeseal
./scripts/02-install-k3s.sh      # k3s with apiserver OIDC
./scripts/03-bootstrap-argocd.sh # ArgoCD + root app
./scripts/04-seal-secrets.sh     # seal secrets, then commit + push
```

Architecture: [docs/architecture.md](docs/architecture.md).
