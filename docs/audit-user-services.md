# Audit: Move Tilt Services from User Units to System Units

## Date
2026-05-15

## Objective

Move 7 systemd services from user-scoped units (`~/.config/systemd/user/`) to system-scoped units (`/etc/systemd/system/`) with `User=casibbald`. This prevents LLMs (running as casibbald) from stopping or restarting the services — `systemctl stop/start` on system units requires root (sudo), but the tilt processes themselves run as casibbald.

---

## Current State

**7 unit files** in `/home/casibbald/.config/systemd/user/`:

| # | File | Type | Description | Port | Working Directory |
|---|------|------|-------------|------|-------------------|
| 1 | `microscaler-shared-kind-infra.service` | oneshot (RemainAfterExit) | Kind cluster infra (registry + cluster + wire + namespaces) | — | — |
| 2 | `tilt-brrtrouter.service` | simple | Tilt dev env for BRRTRouter | 10353 | `/home/casibbald/Workspace/microscaler/BRRTRouter` |
| 3 | `tilt-hauliage.service` | simple | Tilt dev env for Hauliage | 10352 | `/home/casibbald/Workspace/microscaler/hauliage` |
| 4 | `tilt-rerp.service` | simple | Tilt dev env for RERP | 10350 | `/home/casibbald/Workspace/microscaler/rerp` |
| 5 | `tilt-sesame-idam.service` | simple | Tilt dev env for Sesame-IDAM | 10351 | `/home/casibbald/Workspace/microscaler/seasame-idam` |
| 6 | `tilt-shared-kind.service` | simple | Tilt dev env for shared-kind | 10348 | `/home/casibbald/Workspace/microscaler/shared-kind-cluster` |
| 7 | `tilt-tiffany.service` | simple | Tilt dev env for Cylon (legacy unit name) | 10450 | `/home/casibbald/Workspace/microscaler/cylon` |
| 8 | `tilt-dcops.service` | simple | Tilt dev env for DCops | 10354 | `/home/casibbald/Workspace/microscaler/DCops` |

**Active state today:**
- `microscaler-shared-kind-infra.service` — active (exited, RemainAfterExit)
- `tilt-hauliage.service` — active (running)
- `tilt-brrtrouter.service` — inactive (dead)
- `tilt-rerp.service` — inactive (dead)
- `tilt-shared-kind.service` — inactive (dead)
- `tilt-tiffany.service` — inactive (dead)

**Current access control:**
- Any process running as casibbald can stop/restart all 7 services via `systemctl --user`
- Unit files are owned by casibbald — can be modified or deleted

**Target access control:**
- System units in `/etc/systemd/system/` owned by root
- `systemctl stop/start` requires root (sudo) — LLM cannot do it
- Processes run as casibbald (via `User=casibbald`) — preserves file/docker access

---

## User-to-System Unit Differences

| Aspect | User Unit (current) | System Unit (target) |
|--------|-------------------|---------------------|
| Location | `~/.config/systemd/user/` | `/etc/systemd/system/` |
| Owner | casibbald | root |
| Access control | casibbald can stop/start via `systemctl --user` | only root can stop/start via `systemctl` |
| `User=` directive | not supported (always runs as session owner) | required (`User=casibbald`) |
| `Group=` directive | not supported | set to `casibbald` |
| `SupplementaryGroups=` | not supported | set to `docker` for docker socket access |
| Lifecycle | starts/stops with casibbald login session | starts on boot (if enabled), independent of login |
| D-Bus | connects to user bus | uses system bus (tilt doesn't need this) |
| Journal | goes to user journal | goes to system journal |
| Home access | automatic (casibbald's session) | requires `RequiresMountsFor=/home/casibbald` |
| Docker access | automatic (casibbald's session groups) | requires `SupplementaryGroups=docker` |

---

## Service-by-Service Analysis

### 1. microscaler-shared-kind-infra.service

**Current:**
- `Type=oneshot`, `RemainAfterExit=yes`
- `ExecStartPre=/bin/sh -c "docker info >/dev/null 2>&1"`
- `ExecStart=/home/casibbald/.local/share/microscaler/shared-kind/cluster-start.sh`
- `Environment=PATH=/usr/local/bin:/usr/bin:/bin`

**Migration considerations:**
- Add `User=casibbald`, `Group=casibbald`
- Add `SupplementaryGroups=docker` for docker socket access
- Add `RequiresMountsFor=/home/casibbald`
- Add `After=local-fs.target docker.service`
- Script is casibbald-owned — fine to execute as casibbald
- Minimal PATH is OK since docker is at `/usr/bin/docker`

**Risk:** LOW

---

### 2. tilt-brrtrouter.service

**Current:**
- `Type=simple`
- `WorkingDirectory=/home/casibbald/Workspace/microscaler/BRRTRouter`
- `Environment=TILT_PORT=10353`, `TILT_HOST=0.0.0.0`
- `Environment=KUBECONFIG=/home/casibbald/.kube/config`
- `Environment=HOME=/home/casibbald`
- **BUG (line 13):** PATH line is missing `Environment=` prefix
- `ExecStart=/usr/local/bin/tilt up --host 0.0.0.0 --port 10353`
- `Restart=on-failure`, `RestartSec=10`

**Migration considerations:**
- Add `User=casibbald`, `Group=casibbald`
- Add `SupplementaryGroups=docker` for docker socket access
- Add `RequiresMountsFor=/home/casibbald`
- Add `After=local-fs.target docker.service`
- Fix PATH bug — add `Environment=` prefix
- Standardize PATH to match other tilt services

**Risk:** LOW (after fixing PATH bug)

---

### 3. tilt-hauliage.service

**Current:**
- `Type=simple`
- `WorkingDirectory=/home/casibbald/Workspace/microscaler/hauliage`
- `Environment=TILT_PORT=10352`, `TILT_HOST=0.0.0.0`
- `Environment=KUBECONFIG=/home/casibbald/.kube/config`
- `Environment=HOME=/home/casibbald`
- `Environment=PATH=.../home/casibbald/.cargo/bin` (correct format)
- `ExecStart=/usr/local/bin/tilt up --host 0.0.0.0 --port 10352`

**Migration considerations:**
- Add `User=casibbald`, `Group=casibbald`
- Add `SupplementaryGroups=docker`
- Add `RequiresMountsFor=/home/casibbald`
- Add `After=local-fs.target docker.service`
- PATH is correctly formatted — just needs `RequiresMountsFor` and docker group

**Risk:** LOW

---

### 4. tilt-rerp.service

**Current:**
- `Type=simple`
- `WorkingDirectory=/home/casibbald/Workspace/microscaler/rerp`
- `Environment=TILT_PORT=10350`, `TILT_HOST=0.0.0.0`
- Same env as hauliage (PATH correctly formatted)

**Migration considerations:**
- Same as hauliage, different port/description/WorkingDirectory

**Risk:** LOW

---

### 5. tilt-sesame-idam.service

**Current:**
- `Type=simple`
- `WorkingDirectory=/home/casibbald/Workspace/microscaler/seasame-idam`
- `Environment=TILT_PORT=10351`, `TILT_HOST=0.0.0.0`
- Same env as hauliage (PATH correctly formatted)

**Migration considerations:**
- Same as hauliage, different port/description/WorkingDirectory
- Note: directory is `seasame-idam` (not `sesame-idam`) — the actual repo name, leave as-is

**Risk:** LOW

---

### 6. tilt-shared-kind.service

**Current:**
- `Type=simple`
- `WorkingDirectory=/home/casibbald/Workspace/microscaler/shared-kind-cluster`
- `Environment=TILT_PORT=10348`, `TILT_HOST=0.0.0.0`
- `Environment=KUBECONFIG=/home/casibbald/.kube/config`
- `Environment=HOME=/home/casibbald`
- **BUG (line 13):** PATH line is missing `Environment=` prefix
- `ExecStart=/usr/local/bin/tilt up --host 0.0.0.0 --port 10348`

**Migration considerations:**
- Add `User=casibbald`, `Group=casibbald`
- Add `SupplementaryGroups=docker`
- Add `RequiresMountsFor=/home/casibbald`
- Add `After=local-fs.target docker.service`
- **Fix PATH bug** — same as brrtrouter

**Risk:** LOW (after fixing PATH bug)

---

### 7. tilt-tiffany.service

**Current:**
- `Type=simple`
- `WorkingDirectory=/home/casibbald/Workspace/microscaler/cylon`
- `Environment=TILT_PORT=10450`, `TILT_HOST=0.0.0.0`
- Same env as hauliage (PATH correctly formatted)

**Migration considerations:**
- Same as hauliage, different port/description/WorkingDirectory
- Port 10450 is outside the 10348-10353 range used by the other tilt services — intentional, no conflict

**Risk:** LOW

---

## Bugs Found

### BUG 1: tilt-brrtrouter.service — malformed PATH line (line 13)

The PATH line is missing the `Environment=` prefix:

```
/tmp/zig-linux-x86_64-0.11.0:/opt/local/flutter/bin:/home/casibbald/.local/bin:/home/casibbald/.sdkman/candidates/kotlin/current/bin:/home/casibbald/.cargo/bin:/home/casibbald/.nvm/versions/node/v20.20.2/bin:/home/casibbald/.sdkman/candidates/java/current/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
```

systemd interprets this as a bare key with no value. The PATH is **not being set** on the ExecStart process — tilt resolves (it's on the system PATH), but child processes (zig, flutter, node, kotlin) may not be found if they're not on the system default PATH.

**Impact:** Unknown severity — depends on whether the required tools are on the system PATH. If they're not, builds that invoke them silently fail or behave unexpectedly.

**Fix:** Prefix with `Environment=`.

---

### BUG 2: tilt-shared-kind.service — malformed PATH line (line 13)

Same bug as brrtrouter. Identical missing `Environment=` prefix.

**Impact:** Same as BUG 1.

**Fix:** Prefix with `Environment=`.

---

### BUG 3: PATH inconsistency across tilt services

| Service | PATH suffix | Format |
|---------|------------|--------|
| tilt-brrtrouter | missing `.cargo/bin` | malformed (no `Environment=` prefix) |
| tilt-shared-kind | missing `.cargo/bin` | malformed (no `Environment=` prefix) |
| tilt-hauliage | has `.cargo/bin` | correct |
| tilt-rerp | has `.cargo/bin` | correct |
| tilt-sesame-idam | has `.cargo/bin` | correct |
| tilt-tiffany | has `.cargo/bin` | correct |

The brrtrouter and shared-kind services are missing `.cargo/bin` from PATH (in addition to the malformed `Environment=` prefix). This means `cargo`-based builds would fail for those two services.

**Fix:** Standardize PATH across all tilt services.

---

## Security Model (Target)

| Actor | Can read unit file? | Can start service? | Can stop service? | Can modify unit file? |
|-------|-------------------|-------------------|-------------------|---------------------|
| root (sudo) | Yes | Yes | Yes | Yes |
| casibbald (LLM context) | Yes (644) | No (needs sudo) | No (needs sudo) | No |
| other users | No | No | No | No |

This is the desired outcome. The LLM running as casibbald can read the service definitions but cannot stop or restart them.

---

## Risks of Migration

### Risk 1: Home filesystem not mounted at boot
**Severity:** HIGH

System units start during boot, potentially before casibbald's home filesystem is mounted. All 7 services reference `/home/casibbald/...` paths (working directories, kubeconfig, workspace scripts).

**Mitigation:** `RequiresMountsFor=/home/casibbald` and `After=local-fs.target`. This requires systemd 236+ (Ubuntu 20.04+ has this).

### Risk 2: Docker socket not accessible
**Severity:** MEDIUM

System units run in a different cgroup from casibbald's login session. Even with `User=casibbald`, supplementary groups from the login session (like `docker`) may not be inherited.

**Mitigation:** `SupplementaryGroups=docker` ensures docker group membership in the service's cgroup. The docker socket at `/var/run/docker.sock` is group-accessible via the docker group.

### Risk 3: KUBECONFIG not accessible
**Severity:** LOW

`/home/casibbald/.kube/config` is a regular file. With `RequiresMountsFor=/home/casibbald` it will be available at boot. The file is casibbald-owned and readable by casibbald — no permissions issue.

**Mitigation:** Covered by `RequiresMountsFor=/home/casibbald` and `Environment=KUBECONFIG=/home/casibbald/.kube/config`.

### Risk 4: Services start on boot
**Severity:** LOW

`WantedBy=multi-user.target` means services start on boot, even if no one is working. Tilt processes consume resources (memory, CPU, Docker containers).

**Mitigation:** Don't `enable` the services by default. Use `systemctl enable --now tilt-hauliage` when dev work begins. The services are managed by root but only start when explicitly enabled and triggered.

### Risk 5: Tilt process persists after casibbald logs out
**Severity:** LOW

User units stop when the user session ends. System units do not. If casibbald logs out, the tilt processes continue running.

**Mitigation:** This is acceptable — the services are now managed by root, not by login session. Root can stop them if needed.

---

## Verification Checklist

After migration, confirm:

- [ ] All 7 service files exist in `/etc/systemd/system/` and are root:root 644
- [ ] Old unit files removed from `~/.config/systemd/user/`
- [ ] `systemctl daemon-reload` succeeds
- [ ] Each tilt service starts via `systemctl start tilt-<name>` (as root)
- [ ] Each service process runs as `casibbald` (verify: `ps -o user,comm -C tilt`)
- [ ] Docker commands work within tilt (docker socket accessible)
- [ ] KUBECONFIG is accessible (kubectl works)
- [ ] LLM context (as casibbald) CANNOT stop any tilt service (returns "Access denied")
- [ ] Root context CAN stop/start any tilt service
- [ ] No tilt services running in old user scope
- [ ] Journal logs show correct `SyslogIdentifier` for each service
- [ ] PATH bug is fixed: zig/flutter/node/cargo commands work within tilt
- [ ] `RequiresMountsFor=/home/casibbald` is present on all services
