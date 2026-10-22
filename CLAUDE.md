## Goal
Single-node local K3s cluster managed the GitOps way: Argo CD (app-of-apps) syncs
everything from this repo (`https://github.com/hakanelgin/k3s-gitops.git`, branch `main`).

## Status
The MVP is implemented: Argo CD, Keycloak SSO on a local PostgreSQL database
(CloudNativePG), and a Kubernetes UI. The UI is **Headlamp**, not Kubernetes Dashboard.
Supporting components: cert-manager, trust-manager, Sealed Secrets.

## Docs
- `README.md`: components, endpoints, quick start
- `docs/architecture.md`: sync waves, TLS/trust, DNS, SSO/RBAC mapping, secrets
- `docs/bootstrap.md`: host prerequisites, bootstrap steps, rebuild

Keep these docs in sync when you change behaviour.

## Layout
| Path | Contents |
|---|---|
| `scripts/` | Host-side bootstrap `01`–`04`, shared settings in `lib.sh` (versions, paths) |
| `k3s/` | `config.yaml` (apiserver OIDC flags), `resolv.conf` (upstream DNS for CoreDNS) |
| `bootstrap/root-app.yaml` | Root Application that points at `apps/` |
| `apps/` | One Argo CD Application per component, ordered by sync-wave annotation |
| `platform/<component>/` | Helm `values.yaml`, plain manifests, kustomizations, `*.sealed.yaml` |

## Conventions
- Pin every version: Helm chart `targetRevision`, operator release tags, `K3S_VERSION` in `scripts/lib.sh`.
- Helm Applications use multi-source: the chart plus `$values` from this repo.
- A new component gets an `apps/<name>.yaml` with a sync wave and a `platform/<name>/` directory.
- Hostnames are `<service>.localtest.me` over HTTPS, with certificates from `ClusterIssuer/platform-ca`.
- Never commit plaintext secrets or the root CA. Secrets go in as SealedSecrets made by `scripts/04-seal-secrets.sh`.
- Scripts must be idempotent and use `KUBECONFIG=~/.kube/k3s-gitops.yaml`.
- The cluster changes through Git. Use `kubectl apply` only for bootstrap and break-glass.

## Known gaps
- No database backup: Keycloak data that isn't in the realm import is lost on rebuild.
- Single instance for Keycloak and PostgreSQL (no HA, on purpose for a local cluster).

## Rules
- For non-trivial changes, propose a short plan before writing code.
- If requirements are ambiguous, list your questions instead of guessing.
- Keep plans and docs concise. Use tables for endpoint lists.
