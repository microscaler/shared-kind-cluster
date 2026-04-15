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
k8s_resource('redis-exporter', labels=['data'], resource_deps=['redis'])
k8s_resource('minio', labels=['data'])
k8s_resource('mailpit', labels=['data'])
k8s_resource(
    'mailhog',
    port_forwards=['31027:1025', '31028:8025'],
    labels=['data'],
)
k8s_resource('pact-postgres', labels=['data'])
k8s_resource('pact-broker', labels=['data'], resource_deps=['pact-postgres'])
k8s_resource('inbucket', labels=['data'])
k8s_resource('imgproxy', labels=['data'], resource_deps=['minio'])

# --- observe (namespace: observability) — single label: "observe"
# Port-forwards: localhost → Service (may overlap kind-config hostPort mappings; use one access path).
k8s_resource(
    'prometheus',
    port_forwards=['9090:9090'],
    labels=['observe'],
)
k8s_resource(
    'loki',
    port_forwards=['3100:3100'],
    labels=['observe'],
)
k8s_resource(
    'jaeger',
    port_forwards=[
        '16686:16686',
        '4317:4317',
        '4318:4318',
    ],
    labels=['observe'],
)
k8s_resource(
    'grafana',
    port_forwards=['3000:3000'],
    labels=['observe'],
)
k8s_resource('otel-collector', labels=['observe'], resource_deps=['jaeger'])

# --- pipeline — single label: "pipeline"
k8s_resource('fluvio-sc', labels=['pipeline'])

# --- scheduling — single label: "scheduling"
k8s_resource('faktory-server', labels=['scheduling'])

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
    'kubectl config current-context && kubectl get ns data observability pipeline scheduling gcp 2>/dev/null && kubectl get pods -n data -l app=postgres 2>/dev/null; kubectl get pods -n observability 2>/dev/null || true',
    allow_parallel=True,
)

print('')
print('  Shared Kind cluster (kind-kind)')
print('  kustomize ./k8s: Supabase + platform-data + observability (includes stack Namespaces)')
print('  Tilt groups: data | observe | pipeline | scheduling | gcp (one label per resource)')
print('  Host DB/Redis (when port-forwards enabled): primary :5432, replica-0 :6544, replica-1 :6546, redis :6545')
print('  Tilt UI port: %s (override: tilt up -- --tilt_port=...)' % tilt_port)
print('')
