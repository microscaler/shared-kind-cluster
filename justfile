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
# Kind cluster (default name `kind` → kubectl context `kind-kind`)
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

# Delete the shared cluster (does not remove kind-registry; other stacks may still use it)
cluster-delete:
    kind delete cluster --name kind

# Point kubectl at the shared cluster
context:
    kubectl config use-context kind-kind

# kind get clusters + kubectl get ns data observability
status: context
    @kind get clusters
    @kubectl get ns data observability 2>/dev/null || kubectl get ns

# -----------------------------------------------------------------------------
# Tilt (shared infra: k8s/ namespaces; default UI port 10348)
# -----------------------------------------------------------------------------

# Registry + context + wire + Tilt
tilt-up:
    #!/usr/bin/env bash
    set -euo pipefail
    just registry
    kubectl config use-context kind-kind
    just registry-wire
    tilt up --port=10348

tilt-down:
    tilt down || true

# Registry, cluster if missing, wire, context, Tilt (shared infra UI port 10348)
dev-up:
    #!/usr/bin/env bash
    set -euo pipefail
    just registry
    if ! kind get clusters 2>/dev/null | grep -q '^kind$'; then
        kind create cluster --config kind-config.yaml --wait 120s
    fi
    kubectl config use-context kind-kind
    just registry-wire
    tilt up --port=10348

# Stop shared Tilt (cluster + kind-registry unchanged)
dev-down: tilt-down
