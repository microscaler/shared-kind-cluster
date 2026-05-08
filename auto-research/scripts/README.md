# Auto-research — scripts (observability)

Python-only helpers for the observability iteration loop (avoid ad-hoc shell wrappers for the same steps).

## `observability_iteration.py`

Run from the **shared-kind-cluster repository root** (the directory that contains the `Tiltfile` and `k8s/kustomization.yaml`).

| Mode | Command | Purpose |
|------|---------|---------|
| Checklist (default) | `python auto-research/scripts/observability_iteration.py` | Print phases A–D and suggested `just` / `kubectl` / Grafana checks. |
| Verify repo root | `python auto-research/scripts/observability_iteration.py --verify-root` | Exit `0` only if the directory looks like this repo; use in cron before `tilt up`. |
| Local gates (optional) | `python auto-research/scripts/observability_iteration.py --run-local-gates` | Run `kubectl kustomize k8s` and validate `grafana-dashboard-*.json` with Python `json` (fails on invalid JSON). |

**Cron (conceptual):** after `cd` to repo root, `python auto-research/scripts/observability_iteration.py --verify-root && …` then your Tilt or `kubectl apply` pipeline; append experiment rows to [`../docs/OBSERVABILITY_CONTROL_SURFACE_AND_LOG.md`](../docs/OBSERVABILITY_CONTROL_SURFACE_AND_LOG.md).

**Requires for `--run-local-gates`:** `kubectl` in `PATH` (or install separately). JSON validation does not require `jq`.

Charter: [`../docs/OBSERVABILITY_CONTROL_SURFACE_AND_LOG.md`](../docs/OBSERVABILITY_CONTROL_SURFACE_AND_LOG.md).
