# LLM wiki — activity log (shared-kind-cluster)

Chronological, append-only. Newest entries at the **top** after each work session that touches the wiki or materially changes the stack. Format:

```
## [YYYY-MM-DD] <verb> | <short title>

- What changed (2–5 bullets: files, PRs, cluster facts).
- Which wiki pages were updated.
```

---

## [2026-04-25] add | `auto-research/` (observability) — BRRTRouter-style loop

- Added [`auto-research/`](../../auto-research/) with charter [`auto-research/docs/OBSERVABILITY_CONTROL_SURFACE_AND_LOG.md`](../../auto-research/docs/OBSERVABILITY_CONTROL_SURFACE_AND_LOG.md), Python helper [`auto-research/scripts/observability_iteration.py`](../../auto-research/scripts/observability_iteration.py), and wiki topic [`topics/auto-research-observability-loop.md`](./topics/auto-research-observability-loop.md). Focus: world-class **observability** for **core Kind services** (Prometheus, Loki, Grafana, Jaeger/OTel, exporters under this `k8s/` tree).
- Updated [`AGENTS.md`](../../AGENTS.md) (§8) and [`index.md`](./index.md); pattern compared to [`BRRTRouter/auto-research/`](../../BRRTRouter/auto-research/) when repos are siblings under `microscaler/`.

## [2026-04-25] init | Add AGENTS.md + docs/llmwiki

- Introduced root [`AGENTS.md`](../../AGENTS.md) with infra-specific rules (context `kind-kind`, namespace bootstrap, supabase sibling path, no secrets in git, observability path).
- Added [`README.md`](./README.md), [`SCHEMA.md`](./SCHEMA.md), [`index.md`](./index.md), and [`docs-catalog.md`](./docs-catalog.md) plus first topics: [`topics/shared-kind-cluster-layout.md`](./topics/shared-kind-cluster-layout.md), [`topics/observability-stack.md`](./topics/observability-stack.md).
- Linked from [`../../README.md`](../../README.md) under “For AI assistants and automation”.
