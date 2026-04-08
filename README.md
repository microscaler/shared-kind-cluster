# Shared Kind cluster (microscaler)

Single **default** Kind cluster for local development when you cannot run one cluster per project. Application workloads stay **namespaced** (`pricewhisperer`, `hauliage`, `tiffany`, …). Shared platform pieces that are not tied to a single app live here under:

| Namespace        | Purpose                                      |
|-----------------|----------------------------------------------|
| `data`          | Databases, object storage, Mailpit/MailHog/Inbucket, shared data plane |
| `observability` | Metrics, logs, traces, dashboards            |
| `pipeline`      | Fluvio streaming (CRDs, SC, SPUs, …)         |
| `scheduling`    | Faktory job server                           |
| `gcp`           | GCP API emulators (Pub/Sub, Datastore, Bigtable, …) |

## Installed components and dev credentials

> **Not for production.** The accounts below are **local Kind / dev defaults** from [`microscaler-supabase/k8s/data/deployment-configuration/profiles/dev`](../microscaler-supabase/k8s/data/deployment-configuration/profiles/dev) (`application.secrets.env`, `application.properties`) and hard-coded defaults in manifests (e.g. Grafana). They are **test passwords**: short, predictable, and often suitable only for uncommitted local files—**do not** reuse them in staging or production. Use proper secret management (SOPS, External Secrets, vault, etc.) and strong, unique credentials everywhere else.

| Component | Namespace | Default user | Default password | Notes |
|-----------|-----------|--------------|------------------|-------|
| Supabase PostgreSQL (primary) | `data` | `postgres` | `postgres` | From `infra-secrets`; main cluster DB for the Supabase slice. |
| postgres-meta (DB login) | `data` | `supabase_admin` | `postgres` | `PG_META_*` / `POSTGRES_META_*` in `infra-config` / `infra-secrets`. |
| Pact PostgreSQL | `data` | `pact` (fixed) | `pact` | Role name fixed in Deployment; password from `PACT_POSTGRES_PASSWORD`; broker uses `PACT_BROKER_DATABASE_*` + `SERVICE_PACT_POSTGRES_HOST` in manifests. |
| Pact Broker (HTTP Basic) | `data` | `pact` | `pact` | Web UI/API basic auth via `PACT_BROKER_BASIC_AUTH_*` in `infra-secrets`. |
| MinIO (S3 + console) | `data` | `minio` | `minio-dev-password-change-me` | Root credentials from `MINIO_ROOT_*` in `infra-secrets`. |
| Grafana | `observability` | `admin` | `admin` | `GF_SECURITY_ADMIN_*` in [`k8s/observability/grafana.yaml`](k8s/observability/grafana.yaml). |
| Redis | `data` | — | — | No ACL/password in this dev manifest. |
| Mailpit | `data` | — | — | SMTP/UI without auth in default setup. |
| MailHog | `data` | — | — | SMTP/UI without auth in default setup. |
| Inbucket | `data` | — | — | Web/UI without auth in default setup. |
| imgproxy | `data` | — | — | Image proxy only. |
| Parquet lake (workloads) | `data` | — | — | Uses shared `data` plane storage; no separate UI login here. |
| Prometheus, Loki, Jaeger, OpenTelemetry Collector | `observability` | — | — | No auth in these dev manifests. |
| Fluvio (SC, SPUs, topics, …) | `pipeline` | — | — | Follow [Fluvio](https://www.fluvio.io/) docs for cluster profiles and access. |
| Faktory | `scheduling` | — | — | Dev `development` env; dashboard port exposed via Service—treat as untrusted. |
| GCP emulators | `gcp` | — | — | Emulator defaults per Google tooling; not production GCP. |

## Prerequisites

- [kind](https://kind.sigs.k8s.io/), [kubectl](https://kubernetes.io/docs/tasks/tools/), [Tilt](https://tilt.dev/), [just](https://just.systems/)

## Justfile (shortcuts)

From this directory:

| Command | Description |
|--------|-------------|
| `just` | List recipes |
| `just registry` | Start **`kind-registry`** on **localhost:5001** (idempotent) |
| `just registry-wire` | Attach registry to the `kind` network, **containerd** `hosts.toml` on nodes, **kube-public** ConfigMap |
| `just apply-platform-namespaces` | **`kubectl apply -f k8s/platform-namespaces.yaml`** (`data`, `observability`, …) |
| `just dev-up` | **registry** → create cluster if missing → **registry-wire** → **platform-namespaces** → `tilt up` (port **10348**) |
| `just dev-down` | `tilt down` for this repo (cluster + **kind-registry** left running) |
| `just cluster-create` | **registry** → create **`kind`** cluster if missing → **registry-wire** |
| `just cluster-delete` | `kind delete cluster --name kind` (does **not** stop the registry) |
| `just context` | `kubectl config use-context kind-kind` |
| `just status` | Cluster + `data` / `observability` namespaces |
| `just tilt-up` / `just tilt-down` | **registry** + **registry-wire** + Tilt / `tilt down` |

App repos should not start a second registry; use this stack or ensure **`kind-registry`** is already running before `tilt up` in a product repo.

## Create the cluster (once)

Uses the default cluster name **`kind`** → kubectl context **`kind-kind`**.

```bash
kind create cluster --config kind-config.yaml
```

To use an existing cluster, ensure the current context is `kind-kind`:

```bash
kubectl config use-context kind-kind
```

## Infrastructure Tilt (this repo)

From this directory:

```bash
tilt up
```

- **Tilt UI** defaults to port **10348** (avoids collisions with app Tilts that use other ports). Override: `tilt up --port=10349` or set `tilt_port` in `tilt_config.json` / env patterns your team uses.
- The Tiltfile only allows context **`kind-kind`** so you do not deploy shared infra to the wrong cluster by mistake.

### Tilt and namespaces

Stack namespaces (`data`, `observability`, `pipeline`, `scheduling`, `gcp`) are defined in the **kustomize** tree and applied by **`k8s_yaml(kustomize('./k8s'))`** in the Tiltfile.

**Bootstrap (required for app Tilts):** **`kubectl apply -f k8s/platform-namespaces.yaml`** (or **`just apply-platform-namespaces`**) creates those namespaces **outside Tilt** so sibling repos (e.g. **hauliage**) can deploy into **`data`** before shared infra Tilt runs. **`just dev-up`** / **`just tilt-up`** here runs that apply automatically before **`tilt up`**.

**Do not** remove `Namespace` objects from that build to “take them out of Tilt.” Tilt reconciles applies against the YAML it sees; if namespaces disappear from the manifest, Tilt’s cleanup can **delete those namespaces** from the cluster, and the next apply fails with **`namespaces "…" not found`** (for example on `bigtable-emulator` in `gcp`).

Cluster standup is: **Kind cluster** + **`kubectl apply -f k8s/platform-namespaces.yaml`** + **`tilt up`** (or `kubectl apply -k k8s` once), which (re)creates namespaces idempotently. After a bad state, run **`tilt up`** again or **`kubectl apply -k k8s`** from this repo with context **`kind-kind`**.

## Relationship to app repos

1. **`kubectl apply -f k8s/platform-namespaces.yaml`** (or **`just apply-platform-namespaces`**) must succeed on **`kind-kind`** before any app manifest targets **`data`**. **Hauliage** runs this automatically via **`just dev-up`** (see **`SHARED_KIND_CLUSTER_ROOT`** if your checkout layout differs).
2. Bring up **this** Tilt (`just dev-up` or `tilt up` from **shared-kind-cluster**) so shared workloads exist in those namespaces.
3. Run each product’s Tilt (`PriceWhisperer`, `hauliage`, …) against **`kind-kind`**, with that product’s namespace for app resources.

When you migrate an app from a dedicated Kind cluster to the shared one, update that app’s `allow_k8s_contexts` to include `kind-kind` and align `kind-config.yaml` port mappings with this file so host ports stay consistent.

## What `kustomize ./k8s` deploys

1. **Stack `Namespace` objects** — `data` (from microscaler-supabase), `observability`, `pipeline`, `scheduling`, `gcp`. Keep them in this output when using Tilt (see **Tilt and namespaces** above).
2. **`StorageClass` `local-storage`** — required by Supabase PVs/PVCs.
3. **Supabase data plane** — [`microscaler-supabase/k8s/overlays/shared-kind`](../microscaler-supabase/k8s/overlays/shared-kind) → Postgres, parquet lake, exporters, … in namespace **`data`**.
4. **Platform data** — [`k8s/platform-data/`](k8s/platform-data) (Redis, MinIO, Pact, Fluvio, Faktory, GCP emulators, PVs/PVCs, monitoring PVs). Source of truth for these manifests lives in **this repo** (moved out of PriceWhisperer).
5. **Observability** — `k8s/observability/`: namespace **`observability`**, **Prometheus**, **Loki**, **Grafana**, **OpenTelemetry Collector**.

Requires a side-by-side clone of **`microscaler-supabase`** next to **`shared-kind-cluster`** (same parent folder as in this monorepo layout). PriceWhisperer is optional for kustomize (platform-data is self-contained here).

**`infra-config` / `infra-secrets`** (namespace `data`) are generated by **`microscaler-supabase/k8s/data/deployment-configuration/profiles/dev`** (`application.properties` + `application.secrets.env`). The shared **`Tiltfile` runs `kubectl apply -k` on that directory at load time** (before `kustomize ./k8s` is applied) so those objects always exist; copy **`application.secrets.env.example`** → **`application.secrets.env`** if missing. Platform-data workloads need keys such as:

- **Secret `infra-secrets`:** **`PACT_*`**, **`MINIO_ROOT_USER`**, **`MINIO_ROOT_PASSWORD`**, …
- **ConfigMap `infra-config`:** **`MAILPIT_DATABASE`**, **`MAILPIT_TIMEZONE`**, **`INBUCKET_*_ADDR`**, **`IMGPROXY_*`**, …

If keys are missing after pulling newer manifests, extend `application.properties` / `application.secrets.env` (see `application.secrets.env.example`), then re-apply so Kubernetes updates the objects — e.g. from **`microscaler-supabase/k8s/data`**: `kubectl apply -k deployment-configuration/profiles/dev` (or let Tilt re-run `kustomize ./k8s` for **shared-kind-cluster**), then **`kubectl rollout restart`** affected deployments in namespace **`data`**.

### Pact Broker / `pact-postgres` logs

On a **new** database, **`pact-postgres`** logs may include PostgreSQL **`ERROR: relation "schema_migrations" does not exist`** (and similarly **`schema_info`**). The Pact Broker app uses **Sequel**; it probes for migration metadata before creating tables, and Postgres logs failed `SELECT`s at **ERROR** even though the app continues and runs migrations. After startup, **`kubectl logs -n data deployment/pact-broker`** should show a healthy Puma server and **`kubectl get pods -n data -l app=pact-broker`** should be **Running**. If the broker **CrashLoopBackOff**s, investigate broker logs (not only Postgres). Some log viewers also redact paths containing the substring `POSTGRES`, which can make paths like `/var/run/postgresql/...` look corrupted—compare with raw **`kubectl logs`**.

**Host / DNS in logs:** If **`PACT_POSTGRES_PASSWORD`** is the literal string **`postgres`**, some UIs redact that substring **everywhere**, including inside the hostname **`pact-postgres`**, so logs may show a nonsense host like `pact-<redacted>...` and **`Name does not resolve`**. Confirm the real env with **`kubectl exec -n data deploy/pact-broker -- printenv PACT_BROKER_DATABASE_HOST`** (should be **`pact-postgres`**). The broker Deployment sets host/port/DB name as literals in **`pact-broker.yaml`**; only the password comes from **`infra-secrets`**. Ensure **`kubectl get svc -n data pact-postgres`** exists and **`pact-postgres`** pods are ready before the broker.

## Layout

| Path              | Role |
|-------------------|------|
| `justfile`        | `just dev-up` / `just dev-down`, cluster create/delete, registry, context, Tilt |
| `kind-config.yaml`| Merged `extraPortMappings` for app dev (see kind-config comments) |
| `Tiltfile`        | `kustomize ./k8s` (data + observability) |
| `k8s/kustomization.yaml` | Composes StorageClass + Supabase overlay + **`platform-data/`** + `observability/` (includes stack Namespaces) |
| `k8s/observability/` | Prometheus, Loki, Grafana, OTel |

## App repositories

These repos symlink `kind-config.yaml` → `../../shared-kind-cluster/kind-config.yaml` (or `../…` from repo root next to `shared-kind-cluster`):

- `hauliage`, `tiffany`, `lifeguard`, `PriceWhisperer`

`BRRTRouter` keeps a **copy** of the merged config at `k8s/cluster/kind-config.yaml` for standalone CI clones; keep it in sync when editing ports here. Local Tilt in BRRTRouter does **not** create the cluster — from **this** repo run **`just dev-up`** (shared infra on port **10348**), or **`just cluster-create`** if you only need the cluster without that Tilt, then run **`just dev-up`** in BRRTRouter for the app.

## License

MIT — see [`LICENSE`](LICENSE).
