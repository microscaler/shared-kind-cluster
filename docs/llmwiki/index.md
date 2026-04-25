# LLM wiki — index (shared-kind-cluster)

Catalog of all wiki pages. Per [`SCHEMA.md`](./SCHEMA.md), read this **before** opening random files when answering a question.

## Core

- [`SCHEMA.md`](./SCHEMA.md) — Source-of-truth order, page conventions, agent workflow.
- [`README.md`](./README.md) — Session entry: reading order for agents.
- [`log.md`](./log.md) — Append-only activity log.
- [`docs-catalog.md`](./docs-catalog.md) — Map of `docs/adr/`, `docs/design/`, and key `k8s/` paths.

## Topics

- [`topics/shared-kind-cluster-layout.md`](./topics/shared-kind-cluster-layout.md) — Repo map: namespaces, kustomize composition, `just` / Tilt, sibling `microscaler-supabase`.
- [`topics/observability-stack.md`](./topics/observability-stack.md) — Prometheus, Loki, Promtail, Grafana; embedded JSON location; common pitfalls (metric names, datasource UIDs, Grafana 12 `byName`).
- [`topics/auto-research-observability-loop.md`](./topics/auto-research-observability-loop.md) — How to run the **auto-research** loop (A–D), charter links, BRRTRouter pattern comparison.

## Cross-references (outside this repo)

- [Hauliage `docs/llmwiki/`](../../../hauliage/docs/llmwiki/) — application stack; not duplicated here.
- [README at repo root](../../README.md) — default credentials and port table for humans.

## Planned

- [ ] `topics/port-forwards-and-host-access.md` — single page for all Tilt port mappings vs `kind-config` (when we outgrow the README table).
- [ ] `reconciliation/` — only if a formal doc and manifests drift repeatedly and need a standing reconciliation note.
