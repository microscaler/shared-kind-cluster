# Shared Kind cluster (microscaler)

Single **default** Kind cluster for local development when you cannot run one cluster per project. Application workloads stay **namespaced** (`pricewhisperer`, `hauliage`, `tiffany`, …). Shared platform pieces that are not tied to a single app live here under:

| Namespace        | Purpose                                      |
|-----------------|----------------------------------------------|
| `data`          | Databases, object storage, Mailpit/MailHog/Inbucket, shared data plane |
| `observability` | Metrics, logs, traces, dashboards            |

## Prerequisites

- [kind](https://kind.sigs.k8s.io/), [kubectl](https://kubernetes.io/docs/tasks/tools/), [Tilt](https://tilt.dev/), [just](https://just.systems/)

## Justfile (shortcuts)

From this directory:

| Command | Description |
|--------|-------------|
| `just` | List recipes |
| `just registry` | Start **`kind-registry`** on **localhost:5001** (idempotent) |
| `just registry-wire` | Attach registry to the `kind` network, **containerd** `hosts.toml` on nodes, **kube-public** ConfigMap |
| `just dev` | **registry** → create cluster if missing → **registry-wire** → `tilt up` (port **10348**) |
| `just cluster-create` | **registry** → create **`kind`** cluster if missing → **registry-wire** |
| `just cluster-delete` | `kind delete cluster --name kind` (does **not** stop the registry) |
| `just context` | `kubectl config use-context kind-kind` |
| `just status` | Cluster + `data` / `observability` namespaces |
| `just tilt-up` / `just tilt-down` | **registry** + **registry-wire** + Tilt / `tilt down` |

App repos should not start a second registry; use this stack or ensure **`kind-registry`** is already running before `tilt up` in a product repo.

## Create the cluster (once)

Uses the default cluster name **`kind`** → kubectl context **`kind-kind`**.

```bash
kind create cluster --config kind-config.yaml
```

To use an existing cluster, ensure the current context is `kind-kind`:

```bash
kubectl config use-context kind-kind
```

## Infrastructure Tilt (this repo)

From this directory:

```bash
tilt up
```

- **Tilt UI** defaults to port **10348** (avoids collisions with app Tilts that use other ports). Override: `tilt up --port=10349` or set `tilt_port` in `tilt_config.json` / env patterns your team uses.
- The Tiltfile only allows context **`kind-kind`** so you do not deploy shared infra to the wrong cluster by mistake.

## Relationship to app repos

1. Bring up **this** Tilt (or apply the same manifests once) so `data` and `observability` exist.
2. Run each product’s Tilt (`PriceWhisperer`, `hauliage`, …) against **`kind-kind`**, with that product’s namespace for app resources.

When you migrate an app from a dedicated Kind cluster to the shared one, update that app’s `allow_k8s_contexts` to include `kind-kind` and align `kind-config.yaml` port mappings with this file so host ports stay consistent.

## What `kustomize ./k8s` deploys

1. **`StorageClass` `local-storage`** — required by Supabase PVs/PVCs.
2. **Supabase data plane** — [`microscaler-supabase/k8s/overlays/shared-kind`](../microscaler-supabase/k8s/overlays/shared-kind) → Postgres, parquet lake, exporters, … in namespace **`data`**.
3. **Platform data** — [`k8s/platform-data/`](k8s/platform-data) (Redis, MinIO, Pact, Fluvio, Faktory, GCP emulators, PVs/PVCs, monitoring PVs). Source of truth for these manifests lives in **this repo** (moved out of PriceWhisperer).
4. **Observability** — `k8s/observability/`: namespace **`observability`**, **Prometheus**, **Loki**, **Grafana**, **OpenTelemetry Collector**.

Requires a side-by-side clone of **`microscaler-supabase`** next to **`shared-kind-cluster`** (same parent folder as in this monorepo layout). PriceWhisperer is optional for kustomize (platform-data is self-contained here).

## Layout

| Path              | Role |
|-------------------|------|
| `justfile`        | `just dev`, cluster create/delete, registry, context, Tilt |
| `kind-config.yaml`| Merged `extraPortMappings` for app dev (see kind-config comments) |
| `Tiltfile`        | `kustomize ./k8s` (data + observability) |
| `k8s/kustomization.yaml` | Composes StorageClass + Supabase overlay + **`platform-data/`** + `observability/` |
| `k8s/observability/` | Prometheus, Loki, Grafana, OTel |

## App repositories

These repos symlink `kind-config.yaml` → `../../shared-kind-cluster/kind-config.yaml` (or `../…` from repo root next to `shared-kind-cluster`):

- `ai/hauliage`, `ai/tiffany`, `lifeguard`, `PriceWhisperer`

`BRRTRouter` keeps a **copy** of the merged config at `k8s/cluster/kind-config.yaml` for standalone CI clones; keep it in sync when editing ports here.
