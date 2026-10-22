# Bootstrap

Prerequisites: Fedora (tested on 43), `sudo`, `kubectl`, `helm`, `git`, `openssl`, `curl`.
All scripts are idempotent and use `KUBECONFIG=~/.kube/k3s-gitops.yaml`, so an
existing `~/.kube/config` is not touched.

1. **Host prep**: `./scripts/01-host-prep.sh`
   - firewalld: trusts 10.42.0.0/16 (pods) and 10.43.0.0/16 (services), opens 80/443/6443
   - creates the root CA in `~/.k3s-gitops/ca/` and adds it to the system trust store
   - installs `kubeseal`
   - Firefox uses its own trust store: import `~/.k3s-gitops/ca/ca.crt` there
     (Settings → Certificates → Authorities) or enable `security.enterprise_roots.enabled`.
2. **k3s**: `./scripts/02-install-k3s.sh` installs the pinned k3s with
   [`k3s/config.yaml`](../k3s/config.yaml) (apiserver OIDC flags).
3. **ArgoCD**: `./scripts/03-bootstrap-argocd.sh` loads the CA into the cluster,
   installs ArgoCD with Helm, applies `bootstrap/root-app.yaml`.
   ArgoCD now syncs `apps/` by sync wave.
4. **Secrets**: once Sealed Secrets runs, `./scripts/04-seal-secrets.sh`
   writes `*.sealed.yaml` files. Commit and push them; Keycloak and Headlamp then
   become healthy.
5. **Restart argocd-server once** after the CA bundle exists, so it picks up
   `SSL_CERT_FILE`: `kubectl -n argocd rollout restart deploy argocd-server`.

## Rebuild from scratch

```bash
/usr/local/bin/k3s-uninstall.sh
./scripts/02-install-k3s.sh
kubectl apply -f ~/.k3s-gitops/sealed-secrets-key.yaml   # restore sealing key first
./scripts/03-bootstrap-argocd.sh
```

Restoring the sealing key lets the committed SealedSecrets decrypt again.
Without it, run `04-seal-secrets.sh` again and commit.
Note: there is no database backup in the MVP, so Keycloak data (anything not in the realm import) is lost.
