# Shared Kind cluster — microscaler (context kind-kind)
# Run from this directory: `just dev-up` / `just dev-down`
#
# Owns the local Docker registry (kind-registry → localhost:5001) used by all microscaler app Tilts.

set shell := ["bash", "-uc"]

default:
    @just --list

# -----------------------------------------------------------------------------
# Local registry (localhost:5001 → registry:2; wired into Kind nodes when cluster exists)
# -----------------------------------------------------------------------------

# Start or reuse the kind-registry container (bridge network, :5001 on host)
registry:
    #!/usr/bin/env bash
    set -euo pipefail
    reg_name='kind-registry'
    reg_port='5001'
    if ! docker ps -q -f name=^${reg_name}$ | grep -q .; then
        echo "Starting local Docker registry (${reg_name} on 127.0.0.1:${reg_port})..."
        docker run -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" registry:2 || docker start "${reg_name}"
    else
        echo "Registry '${reg_name}' already running."
    fi

# Connect registry to the kind network, containerd hosts.toml on nodes, kube-public ConfigMap
registry-wire: registry
    #!/usr/bin/env bash
    set -euo pipefail
    if ! docker ps -q -f name=^kind-registry$ | grep -q .; then
        echo "Run 'just registry' first."
        exit 1
    fi
    docker network connect kind kind-registry 2>/dev/null || true
    if ! kind get clusters 2>/dev/null | grep -q '^kind$'; then
        echo "No Kind cluster 'kind' yet; registry is up. Run 'just cluster-create' or 'just dev-up'."
        exit 0
    fi
    REGISTRY_DIR="/etc/containerd/certs.d/localhost:5001"
    for node in $(kind get nodes -n kind); do
        docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
        printf '%s\n' '[host."http://kind-registry:5000"]' | docker exec -i "${node}" sh -c 'cat > /etc/containerd/certs.d/localhost:5001/hosts.toml'
        docker exec "${node}" systemctl restart containerd || true
        for _ in $(seq 1 30); do
            docker exec "${node}" ctr version >/dev/null 2>&1 && break
            sleep 1
        done
    done
    printf '%s\n' \
        'apiVersion: v1' \
        'kind: ConfigMap' \
        'metadata:' \
        '  name: local-registry-hosting' \
        '  namespace: kube-public' \
        'data:' \
        '  localRegistryHosting.v1: |' \
        '    host: "localhost:5001"' \
        '    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"' \
        | kubectl apply -f -
    echo "Registry wired to Kind cluster 'kind'."

# -----------------------------------------------------------------------------
# Kind cluster (default name `kind` → kubectl context kind-kind)
# -----------------------------------------------------------------------------

# Create the cluster if it does not exist (idempotent); starts registry and wires it after create
cluster-create: registry
    #!/usr/bin/env bash
    set -euo pipefail
    if kind get clusters 2>/dev/null | grep -q '^kind$'; then
        echo "Kind cluster 'kind' already exists."
        just registry-wire
        exit 0
    fi
    echo "Creating Kind cluster (kind)..."
    kind create cluster --config kind-config.yaml --wait 120s
    echo "Context: kind-kind"
    just registry-wire
    kubectl apply -f k8s/platform-namespaces.yaml

# Delete the shared cluster (does not remove kind-registry; other stacks may still use it)
cluster-delete:
    kind delete cluster --name kind

# Recreate cluster to apply kind-config.yaml changes (extraMounts, ports). DESTRUCTIVE.
cluster-recreate:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "WARNING: Deletes the kind cluster and all in-cluster workloads/state."
    just cluster-delete
    just cluster-create
    just cluster-verify-workspace-mount

# Verify Cylon checkout is visible inside the Kind node (extraMounts in kind-config.yaml).
cluster-verify-workspace-mount:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! kind get clusters 2>/dev/null | grep -q '^kind$'; then
        echo "No Kind cluster 'kind'; run 'just cluster-create' first."
        exit 1
    fi
    docker exec kind-control-plane test -f /home/casibbald/Workspace/microscaler/cylon/Cargo.toml
    echo "OK: /home/casibbald/Workspace/microscaler/cylon visible inside Kind node."

# Point kubectl at the shared cluster
context:
    kubectl config use-context kind-kind

# Create `data`, `observability`, `pipeline`, `scheduling`, `gcp` (idempotent). Run before app Tilts or shared Tilt.
apply-platform-namespaces: context
    kubectl apply -f k8s/platform-namespaces.yaml

# kind get clusters + stack namespaces
status: context
    @kind get clusters
    @kubectl get ns data observability pipeline scheduling gcp ai cylon 2>/dev/null || kubectl get ns

# -----------------------------------------------------------------------------
# Cylon shared infra (routellm, Squid, FreeRADIUS) — k8s/cylon-infra/
# HostPorts :4000 / :3128 / :14000 via kind-config NodePort (routing-first).
# -----------------------------------------------------------------------------

# Apply routellm ConfigMap + restart (edit k8s/cylon-infra/routellm/configmap.yaml).
routellm-apply-config: context
    kubectl apply -k k8s/cylon-infra/routellm
    kubectl rollout restart deployment/routellm -n cylon
    kubectl rollout status deployment/routellm -n cylon --timeout=120s

# Verify Kind routellm → LAN vLLM (hostPort :4000 on 127.0.0.1).
routellm-smoke-backends: context
    #!/usr/bin/env bash
    set -euo pipefail
    lan_ip="${MS02_LAN_IP:-192.168.1.189}"
    echo "==> vLLM direct (LAN)"
    curl -sf http://192.168.1.104:8000/v1/models | jq -r '.data[].id' | head -5
    echo "==> routellm pod → vLLM"
    kubectl exec -n cylon deploy/routellm -- python3 -c \
      "import urllib.request; r=urllib.request.urlopen('http://192.168.1.104:8000/v1/models'); print(r.read().decode()[:300])"
    echo "==> routellm /v1/models (hostPort 127.0.0.1:4000)"
    curl -sf "http://127.0.0.1:4000/v1/models" | jq -r '.data[].id'
    echo "==> chat completion (Qwen/Qwen3.6-35B-A3B-FP8)"
    curl -sf "http://127.0.0.1:4000/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -d '{"model":"Qwen/Qwen3.6-35B-A3B-FP8","messages":[{"role":"user","content":"Reply with exactly: ROUTER_OK"}],"max_tokens":16}' \
      | jq -r '.choices[0].message.content // .error.message // .'

# Apply all cylon-infra manifests (ConfigMaps + workloads).
cylon-infra-apply: context
    kubectl apply -k k8s/cylon-infra

# Apply Squid + FreeRADIUS after editing k8s/cylon-infra/{proxy,freeradius}/configmap.yaml
cylon-proxy-apply-config: context
    kubectl apply -k k8s/cylon-infra/proxy
    kubectl apply -k k8s/cylon-infra/freeradius
    kubectl rollout restart deployment/proxy deployment/freeradius -n cylon
    kubectl rollout status deployment/proxy -n cylon --timeout=120s
    kubectl rollout status deployment/freeradius -n cylon --timeout=120s

# Multipass hostPort verify (../cylon — mpqemubr0 → kind NodePort hostPorts).
resurrection-llmrouter-multipass-bridge:
    just -f ../cylon/justfile resurrection-llmrouter-multipass-bridge

resurrection-squid-multipass-bridge:
    just -f ../cylon/justfile resurrection-squid-multipass-bridge

resurrection-all-multipass-bridges:
    just -f ../cylon/justfile resurrection-all-multipass-bridges

resurrection-hub-multipass-bridge:
    just -f ../cylon/justfile resurrection-hub-multipass-bridge

# -----------------------------------------------------------------------------
# Tilt (shared infra: kustomize ./k8s includes Namespaces; default UI port 10348)
# -----------------------------------------------------------------------------

# Start infrastructure (registry, cluster, wire, namespaces) via systemd
infra-up:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Starting shared Kind cluster infrastructure..."
    systemctl --user start microscaler-shared-kind-infra.service
    for i in $(seq 1 60); do
        if kind get clusters 2>/dev/null | grep -q '^kind$'; then
            echo "Kind cluster is ready."
            exit 0
        fi
        sleep 2
    done
    echo "WARNING: Kind cluster did not become ready within 2 minutes"
    exit 1

infra-down:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Stopping app Tilt services that depend on Kind..."
    for unit in tilt-shared-kind tilt-hauliage tilt-brrtrouter tilt-rerp tilt-sesame-idam tilt-cylon tilt-dcops; do
        systemctl --user stop "${unit}.service" 2>/dev/null || true
    done
    echo "Stopping Kind cluster via systemd (ExecStop stops node containers)..."
    systemctl --user stop microscaler-shared-kind-infra.service

# Install/update cluster scripts + systemd unit on ms02 (~/.local/share + ~/.config/systemd/user)
install-systemd:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="${HOME}/.local/share/microscaler/shared-kind"
    unit_dest="${HOME}/.config/systemd/user"
    mkdir -p "${dest}" "${unit_dest}"
    install -m 0755 deploy/cluster-start.sh "${dest}/cluster-start.sh"
    install -m 0755 deploy/cluster-stop.sh "${dest}/cluster-stop.sh"
    install -m 0644 deploy/microscaler-shared-kind-infra.service "${unit_dest}/microscaler-shared-kind-infra.service"
    systemctl --user daemon-reload
    echo "Installed ${dest}/{cluster-start,cluster-stop}.sh and systemd unit."

# Stop Kind node containers via systemd (registry stays up; cluster data preserved)
kind-stop:
    just infra-down

# Start Kind node containers via systemd (applies 64 GiB Docker cap)
kind-start:
    systemctl --user start microscaler-shared-kind-infra.service

# Start Tilt via systemd (port 10348, shared infra UI)
tilt-up:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Starting shared Kind Tilt via systemd (port 10348)..."
    systemctl --user start tilt-shared-kind.service
    echo "Tilt UI on http://0.0.0.0:10348 (waiting for ready)..."
    for i in $(seq 1 60); do
        if curl -sf http://localhost:10348/api/v1/info >/dev/null 2>&1; then
            echo "Tilt is ready at http://0.0.0.0:10348"
            exit 0
        fi
        sleep 2
    done
    echo "WARNING: Tilt did not become ready within 2 minutes"
    exit 1

tilt-down:
    systemctl --user stop tilt-shared-kind.service || true

# Start infrastructure + Tilt
dev-up:
    #!/usr/bin/env bash
    set -euo pipefail
    just infra-up
    just tilt-up

# Stop Tilt, then infrastructure (cluster + kind-registry unchanged)
dev-down:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Stopping shared Kind Tilt..."
    tilt-down
    echo "Stopping shared Kind cluster infrastructure..."
    infra-down
    echo "[OK] Tilt and infrastructure stopped (cluster + registry unchanged)"
