# Shared Kind cluster — Supabase + platform-data + observability.
# Run against the default cluster: kubectl context kind-kind
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

k8s_yaml(kustomize('./k8s'))

# --- data (namespace: data) — single label: "data"
k8s_resource('postgres', labels=['data'])
k8s_resource('postgres-meta', labels=['data'], resource_deps=['postgres'])
k8s_resource('postgres-exporter', labels=['data'], resource_deps=['postgres'])
k8s_resource('redis', labels=['data'])
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
k8s_resource('prometheus', labels=['observe'])
k8s_resource('loki', labels=['observe'])
k8s_resource('jaeger', labels=['observe'])
k8s_resource('grafana', labels=['observe'])
k8s_resource('otel-collector', labels=['observe'], resource_deps=['jaeger'])

# --- pipeline — single label: "pipeline"
k8s_resource('fluvio-sc', labels=['pipeline'])

# --- scheduling — single label: "scheduling"
k8s_resource('faktory-server', labels=['scheduling'])

# --- gcp (namespace: gcp) — single label: "gcp"
k8s_resource('pubsub-emulator', labels=['gcp'])
k8s_resource('datastore-emulator', labels=['gcp'])
k8s_resource('bigtable-emulator', labels=['gcp'])
k8s_resource(
    'cloud-functions',
    labels=['gcp'],
    resource_deps=['pubsub-emulator', 'datastore-emulator', 'bigtable-emulator'],
)

local_resource(
    'cluster-info',
    'kubectl config current-context && kubectl get ns data observability 2>/dev/null && kubectl get pods -n data -l app=postgres 2>/dev/null; kubectl get pods -n observability 2>/dev/null || true',
    allow_parallel=True,
)

print('')
print('  Shared Kind cluster (kind-kind)')
print('  kustomize ./k8s: Supabase + platform-data + observability')
print('  Tilt groups: data | observe | pipeline | scheduling | gcp (one label per resource)')
print('  Tilt UI port: %s (override: tilt up -- --tilt_port=...)' % tilt_port)
print('')
