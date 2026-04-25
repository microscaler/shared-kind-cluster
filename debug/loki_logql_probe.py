#!/usr/bin/env python3
"""Probe Loki LogQL queries matching hauliage-cluster-logs dashboard patterns.

Set LOKI_URL (default http://127.0.0.1:3100). Use kubectl port-forward svc/loki 3100:3100 -n observability.
"""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

LOG_PATH = "/Users/casibbald/Workspace/microscaler/shared-kind-cluster/.cursor/debug-f12bd1.log"
SESSION_ID = "f12bd1"
LOKI_BASE = os.environ.get("LOKI_URL", "http://127.0.0.1:3100").rstrip("/")


def _agent_log(hypothesis_id: str, message: str, data: dict) -> None:
    # region agent log
    payload = {
        "sessionId": SESSION_ID,
        "hypothesisId": hypothesis_id,
        "location": "debug/loki_logql_probe.py",
        "message": message,
        "data": data,
        "timestamp": int(time.time() * 1000),
        "runId": os.environ.get("DEBUG_RUN_ID", "pre-fix"),
    }
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(json.dumps(payload, ensure_ascii=False) + "\n")
    # endregion


def _query_range(logql: str, hypothesis_id: str) -> None:
    now_ns = int(time.time() * 1_000_000_000)
    start_ns = now_ns - 3600 * 1_000_000_000  # 1h
    params = urllib.parse.urlencode(
        {
            "query": logql,
            "start": str(start_ns),
            "end": str(now_ns),
            "limit": "5",
        }
    )
    url = f"{LOKI_BASE}/loki/api/v1/query_range?{params}"
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            parsed = json.loads(body)
            status = resp.status
    except urllib.error.HTTPError as e:
        status = e.code
        body = e.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = {"raw": body[:2000]}
    except OSError as e:
        _agent_log(
            hypothesis_id,
            "loki_request_failed",
            {"logql": logql, "error": str(e)},
        )
        return

    err_msg = None
    streams_with_error_label = None
    streams_total = None
    if isinstance(parsed, dict):
        err_msg = parsed.get("error") or parsed.get("message")
        rt = parsed.get("data", {}).get("resultType")
        if rt == "streams":
            res = parsed.get("data", {}).get("result", [])
            streams_total = len(res)
            streams_with_error_label = 0
            for stream in res:
                if "__error__" in (stream.get("stream") or {}):
                    streams_with_error_label += 1
    _agent_log(
        hypothesis_id,
        "loki_query_range_result",
        {
            "logql": logql,
            "http_status": status,
            "loki_error_field": err_msg,
            "result_type": parsed.get("data", {}).get("resultType") if isinstance(parsed, dict) else None,
            "streams_total": streams_total,
            "streams_with_error_label": streams_with_error_label,
        },
    )


def main() -> None:
    _agent_log("meta", "probe_start", {"loki_base": LOKI_BASE})

    # H1: empty line filter regex mirrors empty Search box -> |~ ""
    base = '{namespace=~".+", pod=~".+", container=~".+"}'
    _query_range(f"{base} |~ \"\"", "H1")
    _query_range(f'{base} |~ "" | json', "H1")

    # H2: json stage on typical stream (non-JSON lines) — query still parses; pipeline errors appear per-stream in UI
    _query_range(f"{base} | json", "H2")

    # H4: same as dashboard stat panel (regex case flag)
    _query_range(
        'sum(count_over_time({namespace=~".+", pod=~".+", container=~".+"} |~ "(?i)error|exception|panic|fail" [1m]))',
        "H4",
    )

    # H5: label_values equivalent — metrics or series; use series API
    try:
        params = urllib.parse.urlencode({"match[]": '{namespace=~".+", pod=~".+", container=~".+"}'})
        url = f"{LOKI_BASE}/loki/api/v1/series?{params}&start={int(time.time() - 3600)}&end={int(time.time())}"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            parsed = json.loads(body)
        _agent_log(
            "H5",
            "loki_series_ok",
            {"http_status": resp.status, "series_count": len(parsed.get("data", []))},
        )
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        _agent_log("H5", "loki_series_http_error", {"http_status": e.code, "body": body[:1500]})
    except OSError as e:
        _agent_log("H5", "loki_series_failed", {"error": str(e)})

    _agent_log("meta", "probe_end", {})


if __name__ == "__main__":
    main()
