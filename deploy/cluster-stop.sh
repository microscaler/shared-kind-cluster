#!/usr/bin/env bash
# Stop Kind node containers on ms02 (registry stays up). Invoked by systemd ExecStop.
set -euo pipefail

export PATH="/snap/bin:/usr/local/bin:/usr/bin:/bin:/home/casibbald/.local/bin:${PATH:-}"

if ! kind get clusters 2>/dev/null | grep -q '^kind$'; then
    echo "No Kind cluster 'kind' — nothing to stop."
    exit 0
fi

echo "Stopping Kind cluster node containers (kind-registry unchanged)..."
while read -r node; do
    [[ -z "${node}" ]] && continue
    if docker ps -q -f "name=^${node}$" | grep -q .; then
        echo "  stopping ${node}"
        docker stop "${node}" >/dev/null
    else
        echo "  ${node} already stopped"
    fi
done < <(kind get nodes -n kind 2>/dev/null || true)

echo "Kind cluster stopped."
