#!/usr/bin/env bash
# Shared Kind cluster infrastructure — idempotent. Used by systemd ExecStart.
set -euo pipefail

export PATH="/snap/bin:/usr/local/bin:/usr/bin:/bin:/home/casibbald/.local/bin:${PATH:-}"

SHARED_KIND="${SHARED_KIND_ROOT:-/home/casibbald/Workspace/microscaler/shared-kind-cluster}"
# Docker cgroup cap for the kind node container (GiB). Override: KIND_MEMORY_LIMIT_GIB=48
KIND_MEMORY_LIMIT_GIB="${KIND_MEMORY_LIMIT_GIB:-64}"

echo "Ensuring shared Kind cluster infrastructure..."

REG_NAME='kind-registry'
REG_PORT='5001'
if ! docker ps -q -f "name=^${REG_NAME}$" | grep -q .; then
    echo "Starting local Docker registry..."
    docker run -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --network bridge --name "${REG_NAME}" registry:2
else
    echo "Registry already running."
fi

if ! kind get clusters 2>/dev/null | grep -q '^kind$'; then
    echo "Creating Kind cluster..."
    kind create cluster --config "${SHARED_KIND}/kind-config.yaml" --wait 120s
    echo "Context: kind-kind"
else
    echo "Kind cluster already exists."
    while read -r node; do
        [[ -z "${node}" ]] && continue
        if ! docker ps -q -f "name=^${node}$" | grep -q .; then
            echo "Starting stopped node ${node}..."
            docker start "${node}" >/dev/null
        fi
    done < <(kind get nodes -n kind 2>/dev/null || true)
fi

kubectl config use-context kind-kind

docker network connect kind kind-registry 2>/dev/null || true
if kind get clusters 2>/dev/null | grep -q '^kind$'; then
    REGISTRY_DIR="/etc/containerd/certs.d/localhost:5001"
    for node in $(kind get nodes -n kind); do
        docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
        printf '%s\n' '[host."http://kind-registry:5000"]' \
            | docker exec -i "${node}" sh -c 'cat > /etc/containerd/certs.d/localhost:5001/hosts.toml'
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
    echo "Registry wired to Kind cluster."
fi

for node in $(kind get nodes -n kind 2>/dev/null || true); do
    echo "Applying Docker memory cap ${KIND_MEMORY_LIMIT_GIB}GiB to ${node}..."
    docker update --memory="${KIND_MEMORY_LIMIT_GIB}g" --memory-swap="${KIND_MEMORY_LIMIT_GIB}g" "${node}"
done

kubectl apply -f "${SHARED_KIND}/k8s/platform-namespaces.yaml"
echo "Platform namespaces applied."

if kind get clusters 2>/dev/null | grep -q '^kind$'; then
    if ! docker exec kind-control-plane test -f /home/casibbald/Workspace/microscaler/cylon/Cargo.toml 2>/dev/null; then
        echo "WARNING: Cylon workspace is not mounted in the Kind node."
        echo "  extraMounts in kind-config.yaml apply only at cluster create."
        echo "  Fix: cd ${SHARED_KIND} && just cluster-recreate"
    fi
fi

echo "Shared Kind cluster infrastructure is ready."
