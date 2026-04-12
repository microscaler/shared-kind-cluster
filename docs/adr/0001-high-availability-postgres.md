# ADR 0001: High Availability PostgreSQL Strategy via Operator

## Status
**Proposed** (Not Implemented)

## Context
As the `microscaler` ecosystem matures, mission-critical applications like `Hauliage` and `PriceWhisperer` will inevitably require High Availability (HA) guarantees for their persistent data tiers moving into production. 

Currently, the `shared-kind-cluster` datastore provisions PostgreSQL using standalone, bare Kubernetes manifests (Deployments, StatefulSets, statically-linked Services). While a replica can be configured to stream Write-Ahead Logs (WAL) from a primary, automating the promotion of that replica upon primary failure (split-brain prevention, leader election, `pg_ctl promote`, fencing, and Service Endpoint rewriting) proves exceptionally complex and fragile using raw Bash scripts inside container lifecycles. 

Kubernetes does not natively support traditional on-prem Virtual IPs (VIPs) like `Keepalived`. Automated High Availability in Kubernetes necessitates a control loop pattern capable of dynamically repointing the `Service` selector to a newly elected primary node instantly.

## Decision
If High Availability PostgreSQL becomes a requirement, we will **abandon manual `.yaml` manifest deployments for the PostgreSQL datastore** and adopt an established **Kubernetes Operator** (specifically **CloudNativePG** or equivalent, like Zalando Postgres Operator).

The Operator pattern delegates the clustering logic (Patroni/repmgr), automated failover, and self-healing fully into a Custom Resource Definition (CRD).

### Implementation Requirements:
1. **Remove Bare Manifests:** Sun-set the manual `postgres-primary-deployment.yaml` and `replica` variants from `platform-data`.
2. **Deploy Operator:** Install the CloudNativePG Operator via Helm or Kustomize into the `observability` or `platform-data` stack.
3. **Declare Cluster:** Define a `Cluster` CRD with `instances: 3` representing the desired database footprint.

## Consequences
### Positive
- **Automated Failover:** Zero-touch primary promotion and Kubernetes Service "VIP" rewriting.
- **Failback Native:** The operator intrinsically utilizes `pg_rewind` to demote failed primaries back into the replication cluster seamlessly once they recover.
- **Simplicity:** The entire HA footprint is defined in ~15 lines of YAML (the CRD) instead of complex lifecycle hooks and initContainers.
- **Warm Standby Ready:** Secondary nodes can be fully shielded from operational read traffic by controlling read-write vs read-only service endpoint access.

### Negative
- **Abstraction:** The underlying Postgres binaries and replication mechanics are abstracted away, which can complicate low-level granular debugging requiring `kubectl exec`.
- **Infrastructure Overhead:** Requires the cluster operator pods to be running persistently alongside the database instances to monitor the ecosystem.
