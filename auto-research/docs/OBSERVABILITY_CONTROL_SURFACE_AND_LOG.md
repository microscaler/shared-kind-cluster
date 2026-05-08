# Observability loop — control surface, budget, and experiment log

This document defines **what we improve** in the **shared Kind cluster** observability stack, **how long one iteration should take**, and **what we have learned**. It supports a **background / scheduled** rhythm: validate manifests, apply to Kind, check live signals, then record outcomes.

**Location:** `auto-research/docs/` (charter for the [`auto-research/`](../README.md) tree).

## Mission

Build **world-class observability** for **core services** on the default Kind platform: full **metrics** (Prometheus and exporters), **logs** (Loki + Promtail), **traces** (Jaeger/OTel as provisioned), and **dashboards** (Grafana) that are **accurate, maintainable, and SLO-friendly**—not “mostly green in the UI.”

**In scope (core “cluster services” for this program):** workloads and scrape targets owned or composed by this repo’s `k8s/` tree: namespace **`observability`**, platform **`data`** (Postgres family, Redis, object storage, mail sinks, Pact, etc., as deployed here), and **`pipeline`** / **`scheduling`** / **`gcp`** when they are part of the same kustomize apply. **Out of scope** unless explicitly added to the control surface table: a single app’s business metrics in another repo (link dashboards there), production cloud clusters, or non-Kind remote environments.

## Policy (this repo, this program)

| Decision | Rule |
|----------|------|
| **Merge workflow** | Prefer **pull requests** for substantive manifest and dashboard changes so reviewers see diffs. Trivial `docs/llmwiki` / log-only updates may be committed with the same policy as the rest of the monorepo. |
| **Quality gate** | A change is “kept” only if **kustomize renders**, **Tilt (or `kubectl apply -k k8s`) converges** on a dev Kind cluster, and **Grafana + Prometheus show expected series** for the touched targets (no mass “No data” regressions in edited panels). |
| **Measurement** | Record **evidence** in this file (PromQL sample, panel title, or screenshot path in log). Prefer **live queries** against the cluster’s Prometheus (or Grafana explore) over assumptions from upstream dashboard JSON. |
| **Safety** | **Never** improve observability by disabling auth, TLS, or data retention in a way that would be copy-pasted to shared dev laptops without review. Kind defaults are still **local-only**. |

## Iteration time budget (minimum **25–30 minutes**)

Cold applies, log shipping lag, and manual Grafana checks mean **one full loop should assume ≥ 25–30 minutes** wall clock.

| Phase | Purpose | Typical contents (adjust to your host) |
|-------|---------|----------------------------------------|
| **A — Sync & apply** | Reproduce the same stack the team uses | `just tilt-up` / `tilt up` with context `kind-kind`, or `kubectl apply -k k8s` after `kustomize` |
| **B — Static validation** | Catch broken YAML/JSON before runtime | `kubectl kustomize k8s` (or `kustomize build k8s`); optional JSON validation of edited `grafana-dashboard-*.json` |
| **C — Live signals** | Prove exporters and scrapes work | `kubectl get pods -n observability` / `data`; Prometheus `api/v1/query` or Grafana Explore for a **small checklist** of metrics per change |
| **D — UX / completeness** | World-class = usable under load and idle | Open Grafana: row visibility, variable defaults, SLO-appropriate time ranges, no duplicate dead panels; note gaps in the experiment log |

**Do not** schedule fully autonomous cadences **shorter** than this budget unless the charter explicitly narrows to “B only” (validation-only PR).

---

## Control surface — what we are allowed to change

Only the rows below are **in charter** for autonomous or semi-autonomous work unless a human expands the table. Everything else needs explicit design review.

| Area | Location (indicative) | What “better” means | Hard constraints |
|------|------------------------|----------------------|------------------|
| **Grafana (deployment + config)** | `k8s/observability/grafana.yaml`, `embedded/grafana-*.yml` | Right version, feature toggles, datasources, provisioning | No accidental exposure beyond Kind dev; keep admin creds as documented |
| **Embedded dashboards (JSON)** | `k8s/observability/embedded/grafana-dashboard-*.json` | **Correct** PromQL/LogQL, **working** variables, no stub panels, Grafana 12+ schema hygiene (`byName`, row duplication fixes) | Must match real metric names from exporters; probe before merging |
| **Prometheus** | `k8s/observability/prometheus.yaml`, `embedded/prometheus-k8s.yml` | Scrape **complete** and **cardinality-safe**; recording rules when needed | No unbounded high-cardinality labels on new scrapes |
| **Loki + Promtail** | `k8s/observability/loki.yaml`, `promtail.yaml`, `embedded/*` | Pipelines, retention labels, K8s log paths | Watch label cardinality and disk |
| **Jaeger + OTel collector** | `k8s/observability/jaeger.yaml`, `otel-collector*.yaml` | Traces from core services; sampling defaults | Keep resource usage bounded on Kind |
| **Exporter config (this repo)** | e.g. `k8s/platform-data/.../postgres-exporter*`, `redis-exporter*`, `*-exporter*`) | Expose metrics needed for SLOs and **dashboards in charter** | Prefer `queries.yaml` / documented collector patterns over one-off `kubectl` |
| **Recording rules + alerts (future)** | e.g. `PrometheusRule` in `k8s/observability/` | SLO windows, burn rates, user-facing alert text | Must be actionable; runbooks in wiki or `docs/` |

**Out of charter (unless reopened here):**

- Copy-paste dashboards that reference **cloud-only** metrics or UIDs.
- Dropping **auth entirely** on Grafana for “faster dev” (use documented dev defaults; revisit via ADR if policy changes).
- **Silencing** all alerts globally to get a green week.
- **High-cardinality** `instance` or `pod` labels in recording rules in ways that OOM Prometheus on Kind.
- Relying on **shell scripts** in this repo for the loop — use [`../scripts/observability_iteration.py`](../scripts/observability_iteration.py) and `just` / `kubectl` as documented.

---

## Experiment log — tried, outcome, and “do not repeat”

Append new rows with **newest at bottom** for a running log. Initial rows are **seed** examples—replace with your team’s real runs.

### What we tried (running log)

| Date (UTC) | Hypothesis / change | Measurement | Outcome |
|------------|--------------------|------------|---------|
| *2026-04-25* | **Scaffold** `auto-research/` + charter + `observability_iteration.py` | N/A (structure) | **Kept** — mirrors BRRTRouter perf loop, scoped to Kind observability. |
| *—* | *—* | *—* | *—* |

### What we will **not** try again (unless charter changes)

| Idea | Why it is off the table |
|------|------------------------|
| **Merge** broken dashboard JSON “to fix later” | Violates the quality gate; fix panel queries in the same change. |
| **Rename** datasource UIDs in JSON without updating `grafana-datasources.yml` | Breaks provisioning; single source of truth. |
| **One-off** `kubectl set image` for Grafana in Kind without a Git change | Drifts from Git; next apply reverts. |
| **Disable** Promtail to “reduce noise” | Destroys log observability; fix pipeline / filters instead. |

---

## How to use this file in a cron / background job

1. **Checkout** the target branch; ensure context is **`kind-kind`** when applying (see `Tiltfile`).
2. **Run** [`../scripts/observability_iteration.py`](../scripts/observability_iteration.py) for the printable checklist; optional `--verify-root` then `--run-local-gates` (kustomize + optional JSON check).
3. **Run phases A–D** with the **≥ 25–30 min** budget.
4. If gates pass: **open a PR** (or commit per team policy) with a message referencing the hypothesis and what was verified in Prometheus/Grafana.
5. **Append** a row to **What we tried**; add to **What we will not try again** if an approach is permanently rejected.
6. **Update** [`../../docs/llmwiki/log.md`](../../docs/llmwiki/log.md) and [`../../docs/llmwiki/topics/observability-stack.md`](../../docs/llmwiki/topics/observability-stack.md) when methodology or file locations change.

Cross-reference: BRRTRouter’s perf loop for **pattern** only — [`../../../BRRTRouter/auto-research/docs/PERF_CONTROL_SURFACE_AND_LOG.md`](../../../BRRTRouter/auto-research/docs/PERF_CONTROL_SURFACE_AND_LOG.md).
