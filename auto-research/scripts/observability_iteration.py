#!/usr/bin/env python3
"""shared-kind-cluster auto-research: observability iteration checklist and optional local gates.

Run from the repository root (Tiltfile + k8s/kustomization.yaml).
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[2]


def is_shared_kind_root(root: Path) -> bool:
    tilt = root / "Tiltfile"
    k = root / "k8s" / "kustomization.yaml"
    if not tilt.is_file() or not k.is_file():
        return False
    readme = root / "README.md"
    if not readme.is_file():
        return False
    text = readme.read_text(encoding="utf-8", errors="replace")[:12000]
    return "Kind" in text and "kustomize" in text.lower()


def print_checklist() -> str:
    return """
shared-kind-cluster auto-research — one observability iteration
================================================================
Budget: ≥ 25–30 minutes wall clock (apply + wait for scrapes + Grafana pass)

A — Sync & apply (reproduce team stack on Kind)
   kubectl config use-context kind-kind   # or your documented context
   just tilt-up
   # or: just apply-platform-namespaces && tilt up
   # Wait until observability + data pods are Ready where relevant

B — Static validation
   kubectl kustomize k8s > /dev/null
   # After editing dashboards: ensure JSON parses (use --run-local-gates)

C — Live signals (core cluster services)
   kubectl get pods -n observability
   kubectl get pods -n data
   # Prometheus: query a known metric the change depends on, e.g.:
   # curl -sG 'http://<grafana-or-prom>/api/...'  # see charter

D — World-class pass (Grafana)
   - Open key dashboards; confirm variables + panels match exporters
   - No new mass "No data" on rows you own; fix PromQL/LogQL/UID drift

Record: auto-research/docs/OBSERVABILITY_CONTROL_SURFACE_AND_LOG.md (experiment log)
Wiki:  docs/llmwiki/log.md
How:   docs/llmwiki/topics/auto-research-observability-loop.md
"""


def run_kustomize_build(root: Path) -> int:
    cmd = ["kubectl", "kustomize", "k8s"]
    print(f"+ {' '.join(cmd)}", flush=True)
    p = subprocess.run(
        cmd,
        cwd=root,
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        print(p.stderr or p.stdout, file=sys.stderr)
        return p.returncode
    return 0


def validate_grafana_dashboard_json(root: Path) -> int:
    """Parse each grafana-dashboard-*.json under k8s/observability/embedded/."""
    emb = root / "k8s" / "observability" / "embedded"
    if not emb.is_dir():
        print(f"note: no directory {emb}, skipping JSON validation", flush=True)
        return 0
    errors = 0
    for path in sorted(emb.glob("grafana-dashboard-*.json")):
        try:
            data = path.read_text(encoding="utf-8", errors="strict")
            json.loads(data)
        except (json.JSONDecodeError, OSError) as e:
            print(f"error: {path}: {e}", file=sys.stderr)
            errors += 1
    if errors:
        return 1
    print("ok: all grafana-dashboard-*.json in embedded/ parse as JSON", flush=True)
    return 0


def run_local_gates(root: Path) -> int:
    r = run_kustomize_build(root)
    if r != 0:
        return r
    return validate_grafana_dashboard_json(root)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--verify-root",
        action="store_true",
        help="Exit 0 only if this is the shared-kind-cluster repo root.",
    )
    p.add_argument(
        "--run-local-gates",
        action="store_true",
        help="Run kubectl kustomize k8s + JSON parse grafana-dashboard-*.json.",
    )
    args = p.parse_args()
    root = repo_root_from_script()

    if not is_shared_kind_root(root):
        print(
            f"error: expected shared-kind-cluster root; check Tiltfile + k8s/kustomization.yaml + README: {root}",
            file=sys.stderr,
        )
        return 2

    if args.verify_root:
        return 0

    if args.run_local_gates:
        return run_local_gates(root)

    print(print_checklist().strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
