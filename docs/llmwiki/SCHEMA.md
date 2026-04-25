# LLM wiki schema (shared-kind-cluster)

## Purpose

This wiki is a **persistent, compounding knowledge layer** for the shared Kind cluster infrastructure: Kustomize layout, Tilt behavior, namespace contracts, observability (Prometheus, Loki, Grafana), and how product repos (Hauliage, etc.) expect this stack to behave. It follows the same spirit as [Karpathy's llm-wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f): agents **ingest** what they learn, **query** via `index.md`, and **lint** for drift.

## Source of truth order

When claims conflict, higher rank wins:

1. **Runtime behavior** — what `kubectl` and the live cluster show; live Prometheus/Grafana responses for metric names.
2. **This repository** — `k8s/**/*.yaml`, `Tiltfile`, `justfile`, `kind-config.yaml`, `k8s/observability/embedded/*`.
3. **Formal docs** in [`../adr/`](../adr/) and [`../design/`](../design/).
4. **Human `README.md`** at repo root (can lag; fix wiki when you find drift).
5. **This wiki** (`docs/llmwiki/**`) as reconciled narrative — always updated when 1–3 change.

## Layout

```
docs/llmwiki/
├── SCHEMA.md         ← this file
├── README.md         ← short entry, reading order
├── index.md          ← every page, one-line summary
├── log.md            ← append-only session log
├── docs-catalog.md   ← index of `docs/` + key manifest paths
└── topics/           ← cross-cutting, flat (no sub-subfolders)
    ├── shared-kind-cluster-layout.md
    └── observability-stack.md
```

## Page conventions (lightweight)

For each topic page, prefer:

- **Status**: `verified` | `partially-verified` | `unverified`
- **Source**: paths into `k8s/`, `README` sections, ADR links
- **Last updated**: `YYYY-MM-DD`
- **Plain English** first, then file anchors (`Tiltfile` resources, `k8s/observability/grafana.yaml`).

Use `> **Open:**` for unresolved questions; `> **Drift:**` when README and manifests disagree.

## Agent workflow

**Start:** `AGENTS.md` → this `SCHEMA.md` → `index.md` → tail `log.md` → topic pages for the task.

**End:** Update touched topic pages, append `log.md` with date + bullets (what changed, which files), fix obvious drift or flag it.

**Large changes** to cluster behavior (new namespaces, new observability components): add or update an ADR under `docs/adr/` when the decision is architectural, and link it from the wiki.
