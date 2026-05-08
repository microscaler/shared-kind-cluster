# Auto-research observability loop

- **Status:** `partially-verified` (process doc; host URLs and credentials depend on your Kind port-forwards)
- **Last updated:** 2026-04-25

## Purpose

Define **how** to run the **autonomous or scheduled observability research** loop for the shared Kind cluster: time budget, charter location, wiki updates, and evidence (Prometheus / Grafana) expected before a change counts as done.

## Source docs

- Charter + tables: [`auto-research/docs/OBSERVABILITY_CONTROL_SURFACE_AND_LOG.md`](../../../auto-research/docs/OBSERVABILITY_CONTROL_SURFACE_AND_LOG.md)
- Scripts: [`auto-research/scripts/README.md`](../../../auto-research/scripts/README.md)
- Stack context: [`observability-stack.md`](./observability-stack.md)
- Layout: [`shared-kind-cluster-layout.md`](./shared-kind-cluster-layout.md)
- Agent rules: [`AGENTS.md`](../../../AGENTS.md)

## How to conduct one iteration

1. **Read** the charter — confirm your work is **in the control surface** table. Do not expand scope (e.g. a random app’s metrics in another repo) without updating the table and getting review.
2. **Context** — use **`kind-kind`** (or the context your `Tiltfile` allowlists). Do not apply this stack to production clusters in an automated job.
3. **Budget** — assume **≥ 25–30 minutes** for A–D in one go (Tilt, scrape lag, manual Grafana pass).
4. **Checklist** — from repo root: `python auto-research/scripts/observability_iteration.py`. Optional: `--verify-root` before scheduled runs; `--run-local-gates` for `kubectl kustomize k8s` + JSON validation of `grafana-dashboard-*.json`.
5. **Measure** — for dashboard or scrape changes, run at least one **live** PromQL/LogQL check that matches the panel or rule you edited; note the result in the experiment log.
6. **Decide** — if validation passes and signals look correct: open a **PR** (or follow team policy) with Conventional Commits; reference the charter row in the body when useful.
7. **Record** — append a row to **What we tried** in the charter; add to **What we will not try again** if you permanently reject an approach.
8. **Wiki** — append [`../log.md`](../log.md); update [`observability-stack.md`](./observability-stack.md) if file locations, Grafana version, or datasource UIDs change.

## Pattern source

The **BRRTRouter** repo uses the same `auto-research/` shape for **performance** (Rust benches, 30+ min, commit-forward on a dedicated track). This repo reuses the **ritual** (charter, Python helper, log) and applies it to **Kind observability**. See:

- [`../../../../BRRTRouter/auto-research/README.md`](../../../../BRRTRouter/auto-research/README.md) (sibling when both `shared-kind-cluster` and `BRRTRouter` sit under the same `microscaler/` parent)

## Gaps / drift

- If the team **never** runs Tilt and only uses `kubectl apply -k k8s`, document that in the charter so cron jobs match.
