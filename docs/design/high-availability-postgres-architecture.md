# Design Document: Automated Postgres High Availability in Kubernetes

## 1. Executive Summary
This document outlines the blueprint for deploying a High Availability (HA) PostgreSQL cluster within a Kubernetes environment (specifically `shared-kind-cluster` / production variants). It highlights the fundamental differences between traditional on-prem VIP networking and Kubernetes-native Service abstractions, focusing on the Operator pattern to accomplish zero-touch failovers and warm standbys.

## 2. Core Operational Paradigms

### 2.1 The "Virtual IP (VIP)" in Kubernetes
Kubernetes negates the concept of layer-2 floating IP heartbeats (like Keepalived VRRP limits).
Instead, High Availability failover is achieved strictly at the Application Layer via the Kubernetes `Service` object.

- **The Mechanism**: A primary Service is declared (e.g. `hauliage-db-rw`). It resolves via internal CoreDNS as a stable endpoint (e.g. `hauliage-db-rw.data.svc.cluster.local`). 
- **The Failover Action**: Rather than shifting a MAC address to a new machine, the active failover controller updates the `Endpoints` array mapping underlying the `Service` in the Kubernetes API tree. It literally rewrites the routing rule to instantly point TCP/5432 traffic exclusively at the Pod IP of the newly elected Master Replica. 
- **Result:** Downstream applications experience a severed TCP connection, reconnect to the exact same static DNS hostname, and immediately hit the new master.

### 2.2 Isolating the Warm Standby
To satisfy requirements where a replica must remain a silent **"Warm Standby"** (receiving WAL logs but strictly forbidden from serving read queries):
1. **Network Segregation:** The warm standby replica is intentionally excluded from the label selectors of any `-ro` (read-only) Kubernetes Services. 
2. **Result:** The Kubernetes ingress/egress layers have no valid routing tables into the node from application workloads. It sits silently, purely communicating with the primary over replication channels until it is promoted.

## 3. The Operator Pattern Solution
Writing native shell scripts leveraging `patroni` alongside `etcd` directly inside bare Bitnami pods creates tremendous technical debt and is intrinsically fragile during split-brain events or transient network outages.

### The CloudNativePG Architecture
When we elevate to production HA, we deploy the **CloudNativePG** (or equivalent) Kubernetes Operator.

#### 3.1 Components
1. **The Controller (Operator):** A background daemon running cluster-wide that watches custom `Cluster` CRD definitions.
2. **The CRD:** A single YAML entity deployed by engineers detailing the instance size (e.g. `3` pods) and storage constraints.

#### 3.2 Automated Workflows
Upon deploying a 3-instance CRD, the operator autonomously establishes:
- **Pod 1 (Primary)**
- **Pod 2 (Replica A - Read Load Balanced)**
- **Pod 3 (Replica B - Dedicated Warm Standby isolated via label omission)**

#### 3.3 The Failover Event Sequence
1. Primary node enters an unrecoverable crash loop or OOM status.
2. The Operator's liveness probes fail and the controller instantly fences (cuts off) the primary.
3. The Operator compares the WAL cursors on Replica A and B, elects the most synchronized node, and issues `pg_ctl promote`.
4. The Operator universally rewrites the `hauliage-db-rw` Service Endpoints to point to the newly promoted Pod.
5. Service continuity is restored to downstream microservices.
6. When the old Primary restarts, the Operator intercepts it, validates it holds a diverged timeline, and automatically executes `pg_rewind` to mutate it seamlessly back into a Replica.

## 4. Conclusion
While High Availability PostgreSQL is entirely possible in Kubenretes, manual orchestration of the replication roles via `targetPort` configurations and bash scripts must be discarded. To securely migrate into a true VIP-style zero-touch failover design, transitioning the `platform-data/data/postgres` stack fully onto an Operator CRD architecture is mandatory.
