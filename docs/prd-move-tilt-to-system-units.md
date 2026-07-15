# PRD: Move Tilt Services from User Units to System Units

## Executive Summary

Move 7 systemd units from user-scoped (`~/.config/systemd/user/`) to system-scoped (`/etc/systemd/system/`) so that:

1. **Root manages the services** — LLMs with casibbald's terminal access cannot stop or restart tilt services without sudo
2. **Tilt processes run as casibbald** — via `User=casibbald`, preserving file access, docker group membership, and kubeconfig visibility
3. **File ownership is root** — LLMs cannot modify, delete, or disable the units

This is NOT a trivial file move. System units have different lifecycle semantics (boot-start vs login-start), different cgroup isolation, and different resource access rules. This PRD covers all implications.

---

## Problem Statement

The 7 tilt development services are currently user-scoped systemd units in `~/.config/systemd/user/`. This means:

- **Any user with a shell can stop/restart them** via `systemctl --user stop/start tilt-<name>`
- The LLM agent (running as casibbald in the terminal) has full control over these services
- The services start/stop with casibbald's login session, which is the correct lifecycle for dev tools, but the access control is too permissive

**Goal:** Prevent the LLM from stopping or restarting tilt services while keeping them running as casibbald (not root).

---

## Target Architecture

```
/etc/systemd/system/tilt-hauliage.service  (root-owned, system unit)
  ├── User=casibbald
  ├── Group=casibbald
  ├── SupplementaryGroups=docker
  ├── RequiresMountsFor=/home/casibbald
  ├── After=local-fs.target docker.service
  └── ExecStart=/usr/local/bin/tilt up --host 0.0.0.0 --port 10352
```

**Key properties:**
- Service files are in `/etc/systemd/system/` owned by root
- `systemctl stop/start tilt-hauliage` requires root (sudo)
- The tilt process itself runs as casibbald (via `User=casibbald`)
- Tilt gets casibbald's docker group membership (via `SupplementaryGroups=docker`)
- Tilt gets casibbald's kubeconfig and workspace files
- LLM running as casibbald cannot run `systemctl stop tilt-hauliage` (only root can)

---

## Scope

### In scope
1. Migrate 7 services from `~/.config/systemd/user/` to `/etc/systemd/system/`
2. Convert each from user-unit format to system-unit format with `User=casibbald`
3. Fix known bugs during migration (malformed PATH lines in brrtrouter and shared-kind)
4. Add home-mount safety (`RequiresMountsFor`)
5. Add docker socket access (`SupplementaryGroups=docker`)
6. Disable old user units
7. Document the change

### Out of scope
1. Converting to socket activation
2. Adding resource limits (future work)
3. Converting the oneshot infra service to system unit (keep as-is or handle separately — it's one-shot, not a long-running dev service)
4. Modifying tilt itself or any application code

---

## Service List

| Service | Current Unit File | Port | Working Directory |
|---------|-------------------|------|-------------------|
| shared-kind-infra | microscaler-shared-kind-infra.service | N/A (oneshot) | N/A |
| tilt-brrtrouter | tilt-brrtrouter.service | 10353 | /home/casibbald/Workspace/microscaler/BRRTRouter |
| tilt-hauliage | tilt-hauliage.service | 10352 | /home/casibbald/Workspace/microscaler/hauliage |
| tilt-rerp | tilt-rerp.service | 10350 | /home/casibbald/Workspace/microscaler/rerp |
| tilt-sesame-idam | tilt-sesame-idam.service | 10351 | /home/casibbald/Workspace/microscaler/seasame-idam |
| tilt-shared-kind | tilt-shared-kind.service | 10348 | /home/casibbald/Workspace/microscaler/shared-kind-cluster |
| tilt-tiffany | tilt-tiffany.service | 10450 | /home/casibbald/Workspace/microscaler/cylon |

---

## System Unit Template

The template for all tilt services (4 of 5 tilt services share identical structure except port, description, WorkingDirectory, and SyslogIdentifier):

```ini
[Unit]
Description=Tilt <name> Tilt development environment (port <port>)
After=local-fs.target docker.service network-online.target
RequiresMountsFor=/home/casibbald

[Service]
Type=simple
User=casibbald
Group=casibbald
SupplementaryGroups=docker
WorkingDirectory=<working_directory>
Environment=TILT_PORT=<port>
Environment=TILT_HOST=0.0.0.0
Environment=KUBECONFIG=/home/casibbald/.kube/config
Environment=HOME=/home/casibbald
Environment=PATH=/tmp/zig-linux-x86_64-0.11.0:/opt/local/flutter/bin:/home/casibbald/.local/bin:/home/casibbald/.sdkman/candidates/kotlin/current/bin:/home/casibbald/.cargo/bin:/home/casibbald/.nvm/versions/node/v20.20.2/bin:/home/casibbald/.sdkman/candidates/java/current/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
ExecStartPre=/bin/sh -c "docker info >/dev/null 2>&1"
ExecStart=/usr/local/bin/tilt up --host 0.0.0.0 --port <port>
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=tilt-<name>

[Install]
WantedBy=multi-user.target
```

**Notes:**
- `WantedBy=multi-user.target` means the service starts on boot. For dev tools, this may be undesirable. Consider `WantedBy=` on a custom target or manual enable.
- `RequiresMountsFor=/home/casibbald` ensures the home filesystem is mounted before the service starts.
- `SupplementaryGroups=docker` gives the tilt process docker socket access (casibbald is already in the docker group).
- The PATH is standardized across all services. The malformed lines in brrtrouter and shared-kind are fixed.
- `After=local-fs.target` ensures filesystems are mounted. `After=docker.service` ensures docker daemon is running.
- `RequiresMountsFor` requires systemd 236+.

### Oneshot infra service (special case)

```ini
[Unit]
Description=Shared Kind Cluster Infrastructure (registry + cluster + wire + namespaces)
After=local-fs.target docker.service network-online.target
RequiresMountsFor=/home/casibbald

[Service]
Type=oneshot
RemainAfterExit=yes
User=casibbald
Group=casibbald
SupplementaryGroups=docker
ExecStartPre=/bin/sh -c "docker info >/dev/null 2>&1"
ExecStart=/home/casibbald/.local/share/microscaler/shared-kind/cluster-start.sh
Environment=PATH=/usr/local/bin:/usr/bin:/bin
StandardOutput=journal
StandardError=journal
SyslogIdentifier=shared-kind-infra

[Install]
WantedBy=multi-user.target
```

---

## Migration Steps

### Phase 1: Preparation

1. **Stop all tilt services** to avoid conflicts during migration:
   ```
   systemctl --user stop tilt-*.service
   systemctl --user disable tilt-*.service
   ```

2. **Verify no tilt processes are running:**
   ```
   systemctl --user status tilt-*.service
   ps aux | grep tilt
   ```

3. **Verify casibbald is in the docker group:**
   ```
   id casibbald | grep docker
   ```

### Phase 2: Deploy new system units

4. **Copy unit files to /etc/systemd/system/** (as root):
   - Each file gets the template treatment with `User=casibbald`, `SupplementaryGroups=docker`, `RequiresMountsFor`
   - Files are owned by root:root
   - Permissions: 644

5. **Reload systemd daemon:**
   ```
   systemctl daemon-reload
   ```

### Phase 3: Verification

6. **Test one service in isolation** (e.g., tilt-hauliage):
   ```
   systemctl start tilt-hauliage
   systemctl status tilt-hauliage
   ```

7. **Verify the process runs as casibbald:**
   ```
   ps aux | grep tilt
   # Should show casibbald as the process owner
   ```

8. **Verify docker socket access:**
   ```
   systemctl exec tilt-hauliage docker ps
   # Or check journal: journalctl -u tilt-hauliage
   ```

9. **Verify kubeconfig is accessible:**
   ```
   systemctl exec tilt-hauliage kubectl get ns
   # Or check journal logs
   ```

10. **Verify LLM cannot stop the service:**
    ```
    # As casibbald (LLM context):
    systemctl stop tilt-hauliage
    # Should return "Access denied" or similar
    ```

### Phase 4: Cleanup

11. **Remove old user units:**
    ```
    rm ~/.config/systemd/user/tilt-*.service
    rm ~/.config/systemd/user/microscaler-shared-kind-infra.service
    systemctl --user daemon-reload
    ```

12. **Update symlinks** if any remain in `~/.config/systemd/user/default.target.wants/`

### Phase 5: Enable (optional)

13. **Enable services for boot-start** (if desired):
    ```
    systemctl enable tilt-hauliage.service
    # ... repeat for each service
    ```
    
    OR skip enable — dev services shouldn't auto-start on boot. Enable them manually when needed:
    ```
    systemctl enable --now tilt-hauliage.service
    ```

---

## Security Model

| Actor | Can read unit file? | Can start service? | Can stop service? | Can modify unit file? |
|-------|-------------------|-------------------|-------------------|---------------------|
| root (sudo) | Yes | Yes | Yes | Yes |
| casibbald (LLM context) | Yes | No (needs sudo) | No (needs sudo) | No |
| other users | No | No | No | No |

The LLM running as casibbald can **read** the service files (they're world-readable), but cannot start/stop/modify them. This is the desired outcome.

---

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Home filesystem not mounted at boot | HIGH | `RequiresMountsFor=/home/casibbald` + `After=local-fs.target` |
| Docker socket not accessible | MEDIUM | `SupplementaryGroups=docker` — ensures docker group membership in the process cgroup |
| KUBECONFIG not accessible at boot | MEDIUM | Same `RequiresMountsFor` covers this |
| Service starts on boot, wasting resources | LOW | Don't `enable` unless needed. Use `systemctl enable --now <service>` when dev work starts. |
| Tilt process gets stuck after casibbald logs out | LOW | System units are independent of user sessions. The process continues running until stopped. This is actually a feature for long-running dev work. |
| Service fails to start due to missing docker | MEDIUM | `After=docker.service` ensures docker daemon is running. If docker fails, the service fails. |
| LLM still has access to docker socket | LOW | This is out of scope. The goal is to prevent LLM from stopping the service, not to restrict docker access. |

---

## Known Bugs Fixed During Migration

1. **tilt-brrtrouter.service line 13:** PATH line missing `Environment=` prefix
   - Old: `/tmp/zig-linux-x86_64-0.11.0:/opt/local/flutter/bin:...`
   - New: `Environment=PATH=/tmp/zig-linux-x86_64-0.11.0:/opt/local/flutter/bin:...`

2. **tilt-shared-kind.service line 13:** Same malformed PATH line
   - Same fix as brrtrouter

3. **PATH inconsistency across services:** All services now use the same PATH value

---

## Rollback Plan

If something breaks:

1. Stop the new system units:
   ```
   systemctl stop tilt-*.service
   ```

2. Restore old user units from backup (or recreate from git history)

3. Re-enable user units:
   ```
   systemctl --user enable tilt-*.service
   systemctl --user daemon-reload
   ```

4. Verify services are running:
   ```
   systemctl --user status tilt-*.service
   ```

The old user unit files should be preserved until rollback is verified.

---

## Verification Checklist

After migration, confirm all of the following:

- [ ] All 7 service files exist in `/etc/systemd/system/` and are root-owned (644)
- [ ] Old unit files are removed from `~/.config/systemd/user/`
- [ ] `systemctl daemon-reload` succeeds
- [ ] Each tilt service starts successfully
- [ ] Each service process runs as `casibbald` (verify with `ps aux`)
- [ ] Docker commands work within the tilt process (docker socket accessible)
- [ ] Kubeconfig is accessible (kubectl works from within the service)
- [ ] LLM context (as casibbald) cannot stop any tilt service (returns "Access denied")
- [ ] Root context can stop/start any tilt service
- [ ] No tilt services are running in the old user scope
- [ ] Journal logs show the correct `SyslogIdentifier` for each service

---

## Future Improvements (Out of Scope)

1. **Socket activation:** Replace fixed ports with socket-activated services. This would reduce resource usage and allow lazy-starting.
2. **Resource limits:** Add `MemoryMax=`, `CPUQuota=`, `TasksMax=` to prevent runaway tilt processes.
3. **Tilt workspace consolidation:** All 5 tilt services share the same Kind cluster. Consider a single "multi-tilt" service that manages all 5 projects with separate ports.
4. **Health checks:** Add `ExecStartPost` or watchdog to detect when tilt is truly ready (listening on its port).
5. **Centralized PATH management:** Use `EnvironmentFile=` to share common PATH configuration across all services.
