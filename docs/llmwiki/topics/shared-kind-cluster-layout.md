# Shared Kind cluster — layout and workflow

- **Status**: `partially-verified` — aligned with root [`README.md`](../../../README.md); re-verify when `k8s/kustomization.yaml` changes.
- **Source docs**: [`README.md`](../../../README.md), [`../../../Tiltfile`](../../../Tiltfile), [`../../../k8s/kustomization.yaml`](../../../k8s/kustomization.yaml)
- **Last updated**: 2026-04-25

## What it is

One shared Kind cluster (`kind-kind`) hosts **platform** namespaces so multiple Microscaler apps can share Postgres (via Supabase overlay), object storage, Redis, observability, and other data-plane pieces without each repo running a full duplicate cluster.

## Where things live

| Area | Path | Notes |
|------|------|--------|
| Kustomize entry | `k8s/kustomization.yaml` | Composes `StorageClass`, `microscaler-supabase` shared-kind overlay, `platform-data/`, `observability/`. |
| Namespaces (bootstrap) | `k8s/platform-namespaces.yaml` | Must be applied (or `just apply-platform-namespaces`) so sibling app Tilts can target `data`, etc. |
| Data plane (this repo) | `k8s/platform-data/` | Redis, MinIO, Pact, Fluvio, Faktory, GCP emulators, etc. |
| Observability | `k8s/observability/` | Prometheus, Loki, Promtail, Grafana, Jaeger, OTel; embedded files in `embedded/`. |
| Supabase | External overlay | `../microscaler-supabase/k8s/overlays/shared-kind` from monorepo parent (see `README.md`). |
| Local cluster config | `kind-config.yaml` | Kind node port mappings; keep in sync with app repos that symlink this file. |

## Tilt and `just`

- **Tilt** (`tilt up`) applies `kustomize ./k8s` and uses an allowlist for the kubectl context (expected `kind-kind`). Default UI port **10348** (see `README.md`).
- **`just dev-up`** — registry, cluster if missing, platform namespaces, `tilt up` (full stack per `justfile`).

## Gotchas

- **Namespaces removed from the kustomize output** can make Tilt **delete** those namespaces. Keep stack `Namespace` objects in the build (see `README` “Tilt and namespaces” section).
- **Wrong kubectl context** — the Tiltfile guards this; do not `kubectl apply` this repo to non-local clusters without explicit team process.

## Cross-references

- [`observability-stack.md`](./observability-stack.md) — metrics/logs/traces in this stack.
- [ADR 0001](../adr/0001-high-availability-postgres.md) — HA Postgres decision for the shared data plane.
- [Hauliage `AGENTS.md`](../../../../hauliage/AGENTS.md) — how app repos consume this cluster (relative path valid when both repos are siblings under `microscaler/`).
