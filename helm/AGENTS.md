# AGENTS.md — `helm/`

> Kubernetes Helm chart and cluster-side install scripts for the Compliance Toolkit backend service.
> Parent guide: [repo root `AGENTS.md`](../AGENTS.md).
> DB setup used before install: [`db_scripts/AGENTS.md`](../db_scripts/AGENTS.md). Java app: [`mosip-compliance-toolkit/CLAUDE.md`](../mosip-compliance-toolkit/CLAUDE.md).

---

## 1. Chart

| Chart | Path | Deploys | Service image |
|-------|------|---------|----------------|
| `compliance-toolkit` | `helm/compliance-toolkit/` | Compliance Toolkit backend Deployment + Service | `mosip-compliance-toolkit/Dockerfile` |

`Chart.yaml` (`apiVersion: v2`, `version: 0.0.1-develop`) depends on the Bitnami `common` chart for helper templates (`_helpers.tpl`). Templates: `deployment.yaml`, `service.yaml`, `serviceaccount.yaml`, `servicemonitor.yaml` (Prometheus scraping), `virtualservice.yaml` (Istio routing). `install.sh` also references a separate `compliance-toolkit-batch-job` chart published to the `mosip` Helm repo — that chart is **not** part of this repo's `helm/` folder.

---

## 2. Layout

```text
helm/
└── compliance-toolkit/
    ├── Chart.yaml
    ├── values.yaml
    ├── ctk-set-cookie-header.yaml    # Istio EnvoyFilter applied by install.sh
    ├── keycloak-init-values.yaml     # values for the mosip/keycloak-init chart
    ├── copy_cm_func.sh               # shared helper: copy a configmap/secret across namespaces
    ├── copy_cm.sh                    # copies global/artifactory-share/config-server-share configmaps
    ├── install.sh                    # primary cluster install entry point
    ├── keycloak-init.sh              # creates/updates the toolkit Keycloak client
    ├── restart.sh                    # rolling restart of the compliance-toolkit namespace's deployments
    ├── delete.sh                     # uninstalls the compliance-toolkit helm release
    └── templates/
        ├── NOTES.txt
        ├── _helpers.tpl
        ├── deployment.yaml
        ├── service.yaml
        ├── serviceaccount.yaml
        ├── servicemonitor.yaml
        └── virtualservice.yaml
```

CI lints and publishes this chart via [`.github/workflows/chart-lint-publish.yml`](../.github/workflows/chart-lint-publish.yml) (reusable `mosip/kattu` workflow, triggered on changes under `helm/**`). The keycloak values file is separately checked by [`.github/workflows/verify-keycloak-init.yml`](../.github/workflows/verify-keycloak-init.yml), triggered on changes under `helm/compliance-toolkit/keycloak-init**`.

---

## 3. Install

```bash
cd helm/compliance-toolkit
./install.sh [kubeconfig]
```

`install.sh` flow: create the `compliance-toolkit` namespace → disable Istio auto-injection label → prompt for the compliance toolkit host and write it into the `global` ConfigMap (`mosip-compliance-host`) → `copy_cm.sh` (copies `global`, `artifactory-share`, `config-server-share` ConfigMaps in) → apply `ctk-set-cookie-header.yaml` Istio `EnvoyFilter` → run `keycloak-init.sh` → `helm install compliance-toolkit mosip/compliance-toolkit` and `helm install compliance-toolkit-batch-job mosip/compliance-toolkit-batch-job` (both pinned to `CHART_VERSION=0.0.1-develop` in the script) → wait for rollout.

```bash
./keycloak-init.sh   # run standalone if only the Keycloak client needs (re)creating
./restart.sh          # rolling restart of all deployments in the compliance-toolkit namespace
./delete.sh            # interactive teardown of the compliance-toolkit helm release
```

`keycloak-init.sh` copies Keycloak env-var ConfigMaps/secrets into the `compliance-toolkit` namespace, prompts for reCAPTCHA site/secret keys, then runs the `mosip/keycloak-init` chart (`keycloak-init-values.yaml`) to create the `mosip_toolkit_client` and `mosip_toolkit_android_client` Keycloak clients, syncing the resulting secret into the `keycloak` and `config-server` namespaces.

---

## 4. Agent rules

### Do

1. Keep `Chart.yaml`'s `version` bumped when publishing a chart change; `install.sh`'s `CHART_VERSION` (`compliance-toolkit`) and `keycloak-init.sh`'s `CHART_VERSION` (`toolkit-keycloak-init`) are pinned separately — keep both aligned with the published `mosip` Helm repo when releasing.
2. Add new Helm values to `values.yaml` with sane defaults — `install.sh` only overrides `istio.corsPolicy.allowOrigins` via `--set`.
3. Lint the chart locally (`helm lint helm/compliance-toolkit`) before relying on CI's `chart-lint-publish.yml` to catch issues.
4. Coordinate the DB deploy ([`db_scripts/`](../db_scripts/AGENTS.md)) before running `install.sh` — the service expects `mosip_toolkit` to already exist.

### Do not

1. Hardcode environment-specific hosts into chart templates — pass non-sensitive values via `values.yaml`, `--set`, or ConfigMap, as `install.sh` does.
2. Store reCAPTCHA keys or Keycloak client secrets in `values.yaml`, `--set`, or a ConfigMap — they must live only in Kubernetes Secrets. `keycloak-init.sh` prompts for them interactively and stores them as Kubernetes Secrets, not in this repo; never commit a real value for either.
3. Hand-edit a `Chart.lock` file if one is generated for the `common` chart dependency — it is a generated lockfile.
4. Assume `compliance-toolkit-batch-job` lives in this `helm/` folder — it's a separate chart published to the `mosip` Helm repo that `install.sh` also installs.

---

*Last updated: 2026-08-10.*
