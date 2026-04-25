# Source catalog (shared-kind-cluster)

What formal documentation and manifests the wiki is expected to reflect. When any of these change materially, a session should **ingest** into [`topics/`](./topics/) and append [`log.md`](./log.md).

## `docs/`

| Path | Content |
|------|---------|
| [`../adr/0001-high-availability-postgres.md`](../adr/0001-high-availability-postgres.md) | ADR: HA Postgres approach for the shared stack. |
| [`../design/high-availability-postgres-architecture.md`](../design/high-availability-postgres-architecture.md) | Deeper architecture note; complements ADR 0001. |

## Repository root (operational, not in `docs/`)

| Path | Content |
|------|---------|
| [`../../README.md`](../../README.md) | Main overview: components, credentials, `just`/`tilt` workflow, kustomize composition. **Canonical for quick human orientation.** |
| [`../../Tiltfile`](../../Tiltfile) | Allowed k8s contexts, `kustomize ./k8s`, local commands. |
| [`../../justfile`](../../justfile) | `just dev-up`, registry, cluster create/delete, namespace apply. |
| [`../../kind-config.yaml`](../../kind-config.yaml) | Kind cluster config; port mappings for local dev. |

## `k8s/` (selected)

| Path | Content |
|------|---------|
| [`../../k8s/kustomization.yaml`](../../k8s/kustomization.yaml) | Top-level kustomize: wires StorageClass, supabase overlay, platform-data, observability. |
| [`../../k8s/platform-namespaces.yaml`](../../k8s/platform-namespaces.yaml) | Pre-Tilt namespace bootstrap. |
| [`../../k8s/observability/`](../../k8s/observability/) | Prometheus, Loki, Promtail, Grafana, OTel; embedded configs in `embedded/`. |
| [`../../k8s/platform-data/`](../../k8s/platform-data/) | Redis, MinIO, Pact, messaging, Fluvio pieces, etc. |

## Sibling repo (not in this tree)

- **`../microscaler-supabase/k8s/overlays/shared-kind`** — Supabase data-plane overlay consumed by this repo’s kustomize. Path is relative to the standard monorepo layout described in the root `README.md`.

When the wiki cites these paths, use repo-relative links from the wiki file so they resolve in GitHub and local editors.
