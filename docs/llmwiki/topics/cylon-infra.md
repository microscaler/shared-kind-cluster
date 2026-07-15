# Topic: Cylon shared infra (routellm, Squid, FreeRADIUS)

- **Status**: active (2026-06-20)
- **Path**: `k8s/cylon-infra/`
- **Tilt group**: `cylon-infra` (shared-kind-cluster Tiltfile, port **10348**)
- **Namespace**: `cylon` (in-cluster DNS unchanged for cylon-daemon)

## Why here, not cylon repo

Cylon app Tilt (`tilt-cylon`, port 10450) and shared infra Tilt both target `kind-kind`. Deploying routellm/Squid/FreeRADIUS from cylon caused **port-forward conflicts** on `:4000` and `:3128`. These workloads now live in **shared-kind-cluster** so one Tilt owns the host port-forwards.


## Networking direction

**Target:** NodePort + `kind-config` `extraPortMappings` on `0.0.0.0` (routing-first — same pattern as postgres `:5433`). Eliminates Tilt LAN port-forwards and docker socat bridges when Multipass VMs reach `10.177.76.1:<port>` directly.

**Implemented (2026-06-26):** NodePort Services + kind-config hostPorts. No Tilt port-forwards or socat for VM→Kind paths.

See [cylon multipass-kind-networking.md](../../../cylon/llmwiki/topics/multipass-kind-networking.md) for full component audit and migration phases.

## Workloads

**Host exposure (routing-first):** kind `extraPortMappings` on **`0.0.0.0`**: `:4000` routellm, `:3128` Squid, `:14000` hub, `:1812`/`:1813` UDP FreeRADIUS. Multipass VMs use **`10.177.76.1:<port>`**.

| Resource | Service | Host PF | In-cluster |
|----------|---------|---------|------------|
| `routellm` | `routellm:4000` | `127.0.0.1:4000` / `10.177.76.1:4000` (NodePort 30400) | LiteLLM → LAN vLLM |
| `proxy` | `squid-proxy:3128` | `:3128` hostPort (NodePort 30428) | Squid + RADIUS auth |
| `freeradius` | `freeradius:1812/1813` | `:1812`/`:1813` UDP hostPort (NodePort 31812/31813) | Squid in-cluster uses `freeradius` DNS |

## Config files

| Component | Edit |
|-----------|------|
| LiteLLM models | `k8s/cylon-infra/routellm/configmap.yaml` |
| Squid AAA | `k8s/cylon-infra/proxy/configmap.yaml` |
| RADIUS users | `k8s/cylon-infra/freeradius/configmap.yaml` |

ConfigMaps are **explicit YAML** and attached to each workload via Tilt `objects=['*-config:ConfigMap:cylon']` (Deployments auto-discover; ConfigMaps do not).

## Just recipes

```bash
just routellm-apply-config      # after routellm config edits
just routellm-smoke-backends    # vLLM + pod + :4000 smoke
just cylon-proxy-apply-config   # Squid + FreeRADIUS reload
```

Cylon repo delegates: `just -f ../cylon/justfile routellm-apply-config` → here.

## Multipass bridges (cylon repo)

FAR resurrection nodes reach Kind via socat on `mpqemubr0`:

- `10.177.76.1:4000` → `192.168.1.189:4000` (shared Tilt routellm PF on LAN IP)
- `10.177.76.1:3128` → `192.168.1.189:3128` (shared Tilt Squid PF on LAN IP)
- `10.177.76.1:14000` → hub NodePort hostPort (no socat)

Requires **shared-kind-cluster Tilt up** before `just resurrection-llmrouter-multipass-bridge` / `resurrection-squid-multipass-bridge` in cylon.

## Related

- Cylon: `llmwiki/topics/llmrouter-ms02-setup.md`, `far-guest-egress-aaa.md`
- [`shared-kind-cluster-layout.md`](./shared-kind-cluster-layout.md)
