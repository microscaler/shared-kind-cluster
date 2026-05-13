# Shared Kind cluster — Supabase + platform-data + observability.
# Run against the default cluster: kubectl context kind-kind
#
# AGENT NOTE: App Tiltfiles (e.g. ../hauliage) assume shared postgres/redis/meta; they do not duplicate those.
# Hauliage deploys its own Mosquitto broker in namespace `data` from k8s/data/mosquitto.yaml — not this stack.
#
# Stack Namespaces are part of kustomize ./k8s (must stay there — if omitted, Tilt can GC them). See README.
#
# Tilt UI: each workload has exactly ONE label (one of five groups below) to keep the sidebar simple.
#
#   data         — namespace data (Postgres, Redis, mail, Pact, …)
#   observe      — namespace observability (Prometheus, Loki, Grafana, OTel)
#   pipeline     — Fluvio / streaming
#   scheduling   — Faktory
#   gcp          — GCP emulators + functions shim
#   ai           — LLMRouter (ai namespace)

allow_k8s_contexts(['kind-kind'])

update_settings(k8s_upsert_timeout_secs=300)

config.define_string('tilt_port', args=False, usage='Port for Tilt web UI for this stack')
cfg = config.parse()
tilt_port = cfg.get('tilt_port', '10348')
os.putenv('TILT_PORT', tilt_port)

# microscaler-supabase generates infra-config + infra-secrets (kustomize generators). They are not workloads,
# so per-resource force updates can redeploy pods without re-applying those objects; Tilt can also GC them.
# Apply the dev profile first on every Tiltfile load (runs before k8s_yaml below is deployed).
_dev_infra = '../microscaler-supabase/k8s/data/deployment-configuration/profiles/dev'
local_resource(
    'infra-secrets',
    'kubectl apply -k "%s"' % _dev_infra,
    deps=[_dev_infra],
    labels=['data'],
)

k8s_yaml(kustomize('./k8s'))

# Dashboard ConfigMaps are applied via local_resource (not k8s_yaml) to avoid introspection
# cycles: when embedded/ JSONs change, kustomize re-renders → ConfigMaps update → Grafana pod
# restarts → pod state change → k8s_yaml re-introspects → kustomize re-renders → infinite loop.
#
# By applying dashboards via kubectl create configmap --from-file instead, ConfigMap changes
# don't touch the main k8s_yaml resource graph, so no pod restarts are triggered.
# Kubernetes ConfigMap volume mounts are symlinked, so the new JSON content shows up
# in Grafana automatically without any pod restart.
local_resource(
    'apply-postgres-dashboards',
    """kubectl create configmap grafana-postgres-overview \\
       --from-file=postgres-overview.json=k8s/observability/embedded/grafana-dashboard-postgres-overview.json \\
       --dry-run=client -o yaml \\
     | kubectl apply -n observability -f - \\
     && kubectl create configmap grafana-hauliage-db-perf \\
       --from-file=hauliage-db-perf.json=k8s/observability/embedded/grafana-dashboard-hauliage-db-perf.json \\
       --dry-run=client -o yaml \\
     | kubectl apply -n observability -f -""",
    deps=['k8s/observability/embedded/'],
)

# DGX Spark dashboards — three separate ConfigMaps so Grafana's "Sparks" folder
# splits cleanly: cluster overview, vLLM performance, GX10 abrupt-power-off hunt.
# Same kubectl create configmap pattern as above to avoid kustomize re-render
# loops on JSON edits. Mounted optional in grafana.yaml — Grafana boots either way.
# See cylon-local-infra/llmwiki/concepts/sparks-observability-pipeline.md.
local_resource(
    'apply-sparks-dashboards',
    """kubectl create configmap grafana-sparks-cluster \\
       --from-file=spark-cluster.json=k8s/observability/embedded/grafana-dashboard-spark-cluster.json \\
       --dry-run=client -o yaml \\
     | kubectl apply -n observability -f - \\
     && kubectl create configmap grafana-sparks-vllm \\
       --from-file=vllm-performance.json=k8s/observability/embedded/grafana-dashboard-vllm-performance.json \\
       --dry-run=client -o yaml \\
     | kubectl apply -n observability -f - \\
     && kubectl create configmap grafana-sparks-gx10-hunt \\
       --from-file=gx10-power-off-hunt.json=k8s/observability/embedded/grafana-dashboard-gx10-power-off-hunt.json \\
       --dry-run=client -o yaml \\
     | kubectl apply -n observability -f -""",
    deps=[
        'k8s/observability/embedded/grafana-dashboard-spark-cluster.json',
        'k8s/observability/embedded/grafana-dashboard-vllm-performance.json',
        'k8s/observability/embedded/grafana-dashboard-gx10-power-off-hunt.json',
    ],
)

# --- data (namespace: data) — single label: "data"
# Port-forward matches microscaler-supabase Service postgres (see k8s/data/postgres.yaml). Kind may also expose
# NodePort via kind-config hostPort 5433 — use either localhost:5432 (Tilt) or 127.0.0.1:5433 per cluster docs.
#
# Replicas: host ports **6544** / **6546** → pod **5432** (aligns with app repos e.g. Lifeguard `TEST_REPLICA_URL` /
# `TEST_REPLICA_URL_SECOND`). Redis **6545** → **6379** so local tools/tests do not need a separate `kubectl port-forward`.
k8s_resource(
    'postgres-primary',
    port_forwards=['5432:5432'],
    labels=['data'],
)
k8s_resource(
    'postgres-replica-0',
    port_forwards=['6544:5432'],
    labels=['data'],
    resource_deps=['postgres-primary'],
)
k8s_resource(
    'postgres-replica-1',
    port_forwards=['6546:5432'],
    labels=['data'],
    resource_deps=['postgres-primary'],
)

k8s_resource(
    'redis',
    port_forwards=['6545:6379'],
    labels=['data'],
)

k8s_resource(
    'minio',
    port_forwards=['9200:9000', '9201:9001'],
    labels=['data'],
)
k8s_resource(
    'mailpit',
    port_forwards=['31025:1025', '31026:8025'],
    labels=['data'],
)
k8s_resource(
    'mailhog',
    port_forwards=['31029:1025', '31030:8025'],
    labels=['data'],
)
k8s_resource(
    'pact-postgres',
    port_forwards=['5433:5432'],
    labels=['data'],
)
k8s_resource(
    'pact-broker',
    port_forwards=['9293:9292'],
    labels=['data'],
    resource_deps=['pact-postgres'],
)
k8s_resource(
    'inbucket',
    port_forwards=['2501:2500', '7902:7901'],
    labels=['data'],
)
k8s_resource(
    'imgproxy',
    port_forwards=['5002:5001'],
    labels=['data'],
    resource_deps=['minio'],
)
k8s_resource(
    'redis-exporter',
    port_forwards=['9121:9121'],
    labels=['data'],
    resource_deps=['redis'],
)
k8s_resource(
    'postgres-exporter',
    port_forwards=['9187:9187'],
    labels=['data'],
)

# --- observe (namespace: observability) — single label: "observe"
# KIND hostPort mappings provide access on fixed host ports (3000, 3100, 9090, 16686, 4317/4318).
k8s_resource(
    'prometheus',
    port_forwards=['9091:9090'],
    labels=['observe'],
)
k8s_resource(
    'loki',
    port_forwards=['3110:3100'],
    labels=['observe'],
)
k8s_resource(
    'jaeger',
    port_forwards=['16687:16686'],
    labels=['observe'],
)
k8s_resource(
    'otel-collector',
    port_forwards=['4319:4317', '4320:4318', '9465:9464'],
    labels=['observe'],
    resource_deps=['jaeger'],
)

# --- pipeline — single label: "pipeline"
k8s_resource(
    'fluvio-sc',
    port_forwards=['9004:9003'],
    labels=['pipeline'],
)

# --- scheduling — single label: "scheduling"
k8s_resource(
    'faktory-server',
    port_forwards=['7421:7419', '7422:7420'],
    labels=['scheduling'],
)

# --- ai (namespace: ai) — single label: "ai"
# LLMRouter: Python FastAPI service with ML deps (torch, transformers, gradio).
# docker_build() for incremental layer caching; only loads into Kind when image changes.
llmrouter_src = '../LLMRouter'
llmrouter_k8s = 'k8s/ai/'

# Docker build with incremental layer caching — heavy deps are copied/installed first so
# subsequent dev iterations (changing only Python source) skip the 8+ min ML dependency install.
docker_build(
    'llmrouter:latest',
    llmrouter_src,
    dockerfile='%s/Dockerfile' % llmrouter_src,
    build_args={},
)

k8s_resource(
    'llmrouter',
    port_forwards=['8001:8000'],
    labels=['ai'],
)

# --- gcp (namespace: gcp) — single label: "gcp"
#k8s_resource('pubsub-emulator', labels=['gcp'])
#k8s_resource('datastore-emulator', labels=['gcp'])
#k8s_resource('bigtable-emulator', labels=['gcp'])
#k8s_resource(
#    'cloud-functions',
#    labels=['gcp'],
#    resource_deps=['pubsub-emulator', 'datastore-emulator', 'bigtable-emulator'],
#)

local_resource(
    'cluster-info',
    'kubectl config current-context && kubectl get ns data observability pipeline scheduling gcp ai 2>/dev/null && kubectl get pods -n data -l app=postgres 2>/dev/null; kubectl get pods -n observability 2>/dev/null || true',
    allow_parallel=True,
)

print('')
print('  Shared Kind cluster (kind-kind)')
print('  kustomize ./k8s: Supabase + platform-data + observability (includes stack Namespaces)')
print('  Tilt groups: data | observe | pipeline | scheduling | gcp (one label per resource)')
print('  Host DB/Redis (when port-forwards enabled): primary :5432, replica-0 :6544, replica-1 :6546, redis :6545')
print('  Tilt UI port: %s (override: tilt up -- --tilt_port=...)' % tilt_port)
print('')
