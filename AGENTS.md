# Shared Kind cluster — agent rules

> **What this repository is** — a single default [Kind](https://kind.sigs.k8s.io/) cluster for local development: shared `data`, `observability`, `pipeline`, `scheduling`, and `gcp` namespaces, Kustomize + [Tilt](https://tilt.dev/) to apply manifests. Product apps (Hauliage, Tiffany, Lifeguard, …) deploy into the same cluster with their own namespaces.

**Operational knowledge (layout, ports, Supabase relationship, dashboard locations) lives in [`docs/llmwiki/`](./docs/llmwiki/), not in this file.** This file is the short set of rules agents must follow. Synthesized and evolving detail belongs in the wiki, per [`docs/llmwiki/SCHEMA.md`](./docs/llmwiki/SCHEMA.md).

---

## Before you start a session

1. Read [`docs/llmwiki/README.md`](./docs/llmwiki/README.md) — wiki entry (then `SCHEMA.md`, `index.md`, tail of `log.md`).
2. Open [`README.md`](./README.md) for human-oriented quickstart, credentials table, and Tilt port defaults.

---

## Documentation layout

| Path | Role |
|------|------|
| [`README.md`](./README.md) | Primary human overview: prerequisites, `just` recipes, Tilt, namespaces. |
| [`docs/adr/`](./docs/adr/) | Architecture Decision Records for this stack. |
| [`docs/design/`](./docs/design/) | Deeper design notes (e.g. HA Postgres). |
| [`docs/llmwiki/`](./docs/llmwiki/) | LLM-maintained knowledge — **start at `README.md`**. |
| [`k8s/`](./k8s/) | Kustomize tree: `platform-data/`, `observability/`, top-level `kustomization.yaml`. |
| [`Tiltfile`](./Tiltfile) | Allowed k8s context, `kustomize ./k8s`, local resources. |

App-specific dashboards may live in product repos; Grafana-related JSON *maintained in this repo* is under `k8s/observability/embedded/`.

---

## Core rules

### 1. Target context is explicit

**Rule:** Only deploy from this repository when `kubectl` current context is **`kind-kind`** (or the team-agreed shared Kind name for this stack). The `Tiltfile` enforces allowed contexts — do not bypass with `--force` against production clusters.

### 2. Namespace bootstrap order

**Rule:** Stack namespaces must exist before app workloads that reference them. Use `kubectl apply -f k8s/platform-namespaces.yaml` (or `just apply-platform-namespaces`) before or via `just dev-up` / `just tilt-up` as documented in [`README.md`](./README.md). Do not remove `Namespace` objects from the kustomize output to "simplify" Tilt — that can cause Tilt to delete namespaces and break sibling repos.

### 3. Sibling repository: `microscaler-supabase`

**Rule:** The kustomize build expects a **side-by-side clone** of `microscaler-supabase` (same parent directory as this repo) for the shared Supabase data-plane overlay. If paths differ, follow [`README.md`](./README.md) and wiki topics; do not hard-code a different path without updating docs.

### 4. No secrets in git

**Rule:** Do not commit real credentials, tokens, or full `.env` files. Use the repo's established patterns (`application.secrets.env` in supabase profiles, SOPS, or team vault). The [`README.md`](./README.md) dev defaults are for **local Kind only** — never reuse them outside that environment.

### 5. Prefer declarative config over one-off `kubectl` edits to owned resources

**Rule:** For manifests this repo owns, change the YAML/JSON in the tree and re-apply (or let Tilt apply). Patching live objects without a file change drifts from Git and the next apply will fight you.

### 6. Read the wiki for operational truth

**Rule:** `README.md` can lag; if something in this file and the wiki disagrees, **treat the wiki as the place to reconcile** — update `docs/llmwiki/` (and `log.md`) when you learn something that should compound across sessions.

### 7. Observability and dashboards

**Rule:** Data sources and embedded dashboards for this stack live under `k8s/observability/`. When changing Grafana JSON, validate against the Prometheus/Loki data sources the cluster actually provisions (see `k8s/observability/embedded/*`). Favor correct metric names and datasource UIDs over copy-paste from unrelated dashboards.

---

## When ending a session

Per [`docs/llmwiki/SCHEMA.md`](./docs/llmwiki/SCHEMA.md): update touched wiki pages, append [`docs/llmwiki/log.md`](./docs/llmwiki/log.md), and flag open questions with `> **Open:**` where the next agent should notice them.

---

## Cross-references

- [Hauliage `AGENTS.md`](../hauliage/AGENTS.md) and [`docs/llmwiki/`](../hauliage/docs/llmwiki/) — application-layer rules; this repo is infrastructure only.
- [Karpathy llm-wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — why `docs/llmwiki/` exists.
