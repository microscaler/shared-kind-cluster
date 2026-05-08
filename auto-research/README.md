# `shared-kind-cluster` `auto-research/`

Autonomous and semi-autonomous **observability research** for the shared Kind platform: bounded experiments on an explicit **control surface**, a defined **time budget** per iteration, and **evidence in Git** (manifests, dashboards, and this log; not only live cluster edits).

| Path | Role |
|------|------|
| [`docs/`](./docs/README.md) | Charter: control surface, experiment log, “won’t repeat”, cron checklist |
| [`scripts/`](./scripts/README.md) | Python helpers (`observability_iteration.py`) — no ad-hoc shell scripts for the same workflow |

**Conduct:** [`docs/llmwiki/topics/auto-research-observability-loop.md`](../docs/llmwiki/topics/auto-research-observability-loop.md).

**Agent rules:** [`AGENTS.md`](../AGENTS.md) — “Autonomous observability research” section.

**Comparison:** This mirrors the structure of **BRRTRouter** [`auto-research/`](../../BRRTRouter/auto-research/) (perf / hot path), re-scoped to **observability** (metrics, logs, traces, dashboards, and exporter alignment) for **core Kind cluster services** in namespace `data` and `observability` (and shared dependencies scraped from `k8s/`).
