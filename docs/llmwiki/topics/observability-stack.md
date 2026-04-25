# Observability stack (shared-kind-cluster)

- **Status**: `partially-verified` — file paths and purposes match tree layout; data source UIDs and Grafana version should be checked in live manifests.
- **Source**: [`k8s/observability/`](../../../k8s/observability/), especially [`grafana.yaml`](../../../k8s/observability/grafana.yaml) and [`embedded/`](../../../k8s/observability/embedded/)
- **Last updated**: 2026-04-25

## What it is

Namespace **`observability`** runs Prometheus (metrics), Loki (logs), Promtail (log shipping from nodes), Grafana (UI + provisioning), and related pieces (e.g. Jaeger, OpenTelemetry collector) as defined under `k8s/observability/`. Product apps in other namespaces are scraped or ship logs according to the manifests and Prometheus scrape configs in `embedded/`.

## Key paths

| Component | Location |
|----------|----------|
| Grafana Deployment | `k8s/observability/grafana.yaml` |
| Datasource provisioning | `k8s/observability/embedded/grafana-datasources.yml` |
| Dashboard provisioning | `k8s/observability/embedded/grafana-dashboard-providers.yml` |
| Dashboard JSON (this repo) | `k8s/observability/embedded/grafana-dashboard-*.json` |
| Prometheus | `k8s/observability/prometheus.yaml` + `embedded/prometheus-k8s.yml` |
| Loki / Promtail | `k8s/observability/loki.yaml`, `promtail.yaml`, `embedded/loki-k8s-config.yml`, `embedded/promtail-config.yml` |

## Conventions for agents editing dashboards

1. **Data source UIDs** in JSON must match provisioned UIDs (e.g. Prometheus `uid: prometheus` when set in `grafana-datasources.yml` — verify file).
2. **Metric names** must exist in the target exporter (e.g. `postgres-exporter` often exposes `pg_stat_database_*` but not all `pg_stat_user_tables_*` without custom collectors). Probe Prometheus before assuming a panel works.
3. **Grafana 12+** — panel field override matchers use `byName` (lowercase `b`), not `ByName`; feature toggles like `dashboardNewLayouts` are set on the Deployment env (see `grafana.yaml` for current pattern).
4. **Row panels in v1 JSON** — non-collapsed rows with a populated nested `panels` array can duplicate empty “No data” tiles after migration; empty those arrays for row-only groupings (top-level `panels` holds real panels). Prefer eventual migration to v2 / Dynamic Dashboards when the team standardizes on tabs.

## Cross-references

- Root `README` — default Grafana `admin` / `admin` (local only).
- [shared-kind-cluster-layout.md](./shared-kind-cluster-layout.md) — where observability fits in the full kustomize tree.
- [auto-research-observability-loop.md](./auto-research-observability-loop.md) — scheduled / iterative improvements (charter, experiment log, `observability_iteration.py`).
