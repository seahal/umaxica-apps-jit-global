# Fix devcontainer `core` container crash loop (EUID 0 required)

## Context

`devcontainer up` builds successfully but fails during startup: after all containers report
"Started", the CLI's exec into `core` fails with
`Error: can only start exec sessions when their container is running: container state improper`.

Live diagnosis (`podman logs global-devcontainer-core`) shows the actual cause:

```
Container started
core-entrypoint: effective UID 0 is required
```

Exit code 77, and `restart: always` puts the container in a fast crash loop, so by the time the
devcontainer CLI tries to exec into it, it has already died.

`podman inspect global-devcontainer-core` confirms `Config.User` is `"global"`, not `"root"`, even
though `compose.yaml` sets `user: root` for the `core` service.
`.devcontainer/compose.override.yml:11` sets `userns_mode: keep-id` on `core`, and rootless Podman's
`keep-id` handling silently overrides/ignores the explicit `user: root` from the base compose file,
starting the process as the host-mapped user instead of root.

`docker/core/entrypoint.sh` (`/usr/local/bin/core-entrypoint`) requires `EUID == 0` (line 11-14)
because the current design has PID 1 start as root and then drop privileges itself via `setpriv` to
`CORE_WORKLOAD_USER`/ `CORE_WORKLOAD_GROUP` (built from `DOCKER_UID`/`DOCKER_GID`, i.e. host-shaped
UID/GID) — see the comment at `.devcontainer/compose.override.yml:12-14`: "The Compose service keeps
a root control-plane PID 1 ... core-entrypoint drops the development workload to the host-shaped
UID/GID."

Git history shows this override file used to carry both `userns_mode: keep-id` **and**
`user: !reset null`, with a comment explaining exactly this conflict: `keep-id` already maps the
host UID into the container, so `user: root` on top double-maps and breaks bind-mount ownership —
the fix back then was to clear `user:` so the image's baked-in `USER` won. Since then, the
entrypoint architecture changed to the current root-PID1-then-`setpriv`-drop design (which needs
real root, not a keep-id-mapped host user), but the override file was never updated to drop
`userns_mode: keep-id` to match. It's now a leftover from the old design that actively breaks the
new one: `keep-id` prevents `user: root` from taking effect, which fails the entrypoint's
`EUID == 0` check every time.

Two other previously-diagnosed issues in this same failure class
(`plans/podman-g-com-name-spicy-snowglobe.md`, `plans/yes-devcontaner-up-prancy-moore.md`) are
already fixed and confirmed present in the current tree: the `EMAIL_ADDRESS_HMAC_SALT` /
`TELEPHONE_NUMBER_HMAC_SALT` dev env vars, and the supervisor no longer exiting the container when
`bin/dev` crashes. Those are not the cause here.

## Fix

Remove the stale `userns_mode: keep-id` line from the `core` service in
`.devcontainer/compose.override.yml` (currently line 11, plus the two now-inaccurate lines
immediately after it, `# Reset the base tmpfs list...` paragraph is unrelated and stays). This lets
`compose.yaml`'s `user: root` take effect again, satisfying `core-entrypoint`'s `EUID == 0`
requirement, and lets the entrypoint's existing `setpriv --reuid=... --regid=...` drop to the
host-shaped `global` UID/GID (already built via `DOCKER_UID`/ `DOCKER_GID` build args) handle
bind-mount ownership, exactly as the "root control-plane PID 1" design comment already documents.

No other files need to change: the entrypoint script, the Dockerfile's `DOCKER_UID`/`DOCKER_GID`
build args, and `compose.yaml`'s `user: root` are all already correct for this design and don't need
touching.

## Verification

1. `podman compose --project-name umaxica-apps-global-dc -f compose.yaml -f .devcontainer/compose.override.yml -f compose.custom.yaml up -d core`
   (or a full `devcontainer up` rebuild-free run) and confirm `core` stays `Up`/`Healthy` instead of
   restarting.
2. `podman logs --tail 20 global-devcontainer-core` shows no `effective UID 0 is required` and shows
   the supervisor/`bin/dev` starting instead.
3. `podman inspect global-devcontainer-core --format '{{.Config.User}}'` reports `root` (or empty,
   since `compose.yaml` sets it), not `global`.
4. Run a full `devcontainer up` from the repo root to confirm the CLI's post-start exec succeeds
   end-to-end.

Status: implemented and verified in this session (working tree, not committed).

---

# Follow-up: `bundle update` (or any single Procfile.dev process exit) kills the whole devcontainer

## Context

After the fix above landed, the user reported that running `bundle update` inside an interactive
shell in the running `core` container makes "the dev container go down" shortly after. The command's
own output shows `bundle update` itself finishing successfully ("Bundle updated!"), so the crash
isn't a bundle/git failure — something else brings the container down as a side effect.

Root cause, confirmed directly from `podman logs global-devcontainer-core` (two live crash/restart
cycles captured in the current session, both matching this exact pattern):

```
19:31:29        | exited with code 0
19:31:29 system | sending SIGTERM to all processes
19:31:30 web.1  | terminated by SIGTERM
19:31:30 jobs.1 | exited with code 0
19:31:34 system | sending SIGKILL to all processes
Container started
```

`bin/dev` (`bin/dev:15`) ends with `exec bundle exec foreman start -f Procfile.dev "$@"`. Foreman's
default behavior: when **any one** of its managed processes (`Procfile.dev`: `web` / Puma, `vite`,
`jobs` / Solid Queue) exits for _any_ reason — clean exit or crash — foreman sends SIGTERM then
SIGKILL to the whole group and exits itself. Because `docker/core/entrypoint.sh`'s non-root branch
(added in the fix above) does a bare `exec "$@"` with no supervisor in between, foreman _is_ the
container's PID 1. Foreman exiting therefore exits the container; `restart: always` then recreates
it, which the user experiences as "the devcontainer went down."

This is a resilience regression from the same root cause fixed above: the previous design ran the
workload under `tailscale-core-supervisor`, which retried the workload with backoff instead of
exiting when it died (see `.devcontainer/tailscale-core-supervisor.sh:176-231`, `start_workload` +
the main retry loop, and the comment at lines 217-221 explaining exactly this: "The workload's
failure does not tear down ... this supervisor ... the container's own liveness must not depend on
the workload's success."). Disabling `tailscale-core-supervisor` (per the user's "not using
Tailscale, go with the safe direction" decision earlier) removed that resilience layer along with
the root/Tailscale requirement it existed to serve.

`bundle update` doesn't need to be the direct cause of a crash for this symptom to appear — it only
needs to make _any_ one of `web`/`vite`/`jobs` exit while it rewrites thousands of files under
`vendor/bundle` (files those Ruby processes have `require`'d, and which Vite's default file watcher
scope is not configured to exclude — see `config/vite.json` `watchAdditionalPaths: []`, no ignore
for `vendor/`). Whichever process trips first, foreman's all-or-nothing behavior takes the whole
container down.

## Fix

Extract just the workload-retry portion of `tailscale-core-supervisor.sh` (no tailscaled, no root,
no `setpriv` — the non-root path already runs as the correct workload user) into a new small script,
and put it in front of `bin/dev` as the container's PID 1 instead of running `bin/dev` bare. This
restores "one Procfile.dev process dying does not kill the container" without reintroducing the
root/`keep-id` conflict fixed above.

1. New file `docker/core/dev-supervisor.sh` (mirrors `docker/core/entrypoint.sh`'s location/style):
   trap `TERM`/`INT` for clean shutdown, `start_workload` runs `"$@"` via `setsid ... &` (own
   session/process group, same reasoning as `tailscale-core-supervisor.sh:176-179` — foreman's
   shutdown-the-group behavior must not be able to kill the supervisor itself), and a retry loop
   with the same exponential backoff (`WORKLOAD_MAX_BACKOFF_SECONDS=30`,
   `WORKLOAD_BACKOFF_RESET_SECONDS=30`) as `tailscale-core-supervisor.sh:190-231`. No
   `CORE_WORKLOAD_USER`/ `WORKLOAD_GROUP` lookups or `setpriv` needed — this script only ever runs
   already-dropped-to-the-workload-user.
2. `Dockerfile`: add
   `COPY --chown=0:0 docker/core/dev-supervisor.sh /usr/local/bin/core-dev-supervisor` next to the
   existing `core-entrypoint` COPY (line 277), and add it to the `chmod 0555` list (lines 282-285).
3. `.dockerignore`: add `!docker/core/dev-supervisor.sh` next to the existing
   `!docker/core/entrypoint.sh` (line 133).
4. `compose.yaml`: change the `core` service's `command:` (currently `- bin/dev`, lines 15-16) to
   `["/usr/local/bin/core-dev-supervisor", "bin/dev"]`. `docker/core/entrypoint.sh`'s non-root
   branch (`exec "$@"`) needs no change — it already runs whatever command it's given.

`compose.custom.yaml`'s `core` block (already edited in the prior fix to no longer override
`command`) does not need further changes: the base `compose.yaml` command is what wins.

## Verification

1. Rebuild `core`, bring it up, confirm `podman exec global-devcontainer-core ps -eo pid,ppid,cmd`
   shows `core-dev-supervisor` as PID 1 with `foreman` as its child.
2. Inside the container, run `bundle update` (or more directly, `kill` one of the
   `web`/`vite`/`jobs` foreman children) and confirm via `podman ps`/`podman logs` that the
   container keeps running and the workload restarts
   (`core-dev-supervisor: development workload exited with status ...; retrying in Ns`), instead of
   the container exiting.
3. Confirm clean shutdown still works: `podman stop global-devcontainer-core` should stop promptly
   (via the `TERM` trap), not hang for a full `stop_grace_period`/SIGKILL timeout.
4. Re-run `bin/rails test` / normal dev workflow to confirm nothing else regressed.
