# Cloudflare Tunnel restart storm, 2026-08-23

## Incident

The host desktop was left unattended and found with its fan at full speed and the display blacked
out; it booted normally after a reset. The host journal showed
`umaxicaappsglobaldc_cloudflare-tunnel_1` restarting roughly 2,530 times in the fifteen minutes
between 11:20 and 11:35 — a median interval of 0.36 seconds, about 2.8 restarts a second — each one
creating and destroying a network namespace and veth pair.

cloudflared exited every time with:

```text
"cloudflared tunnel run" requires the ID or name of the tunnel to run as the last
command line argument or in the configuration file.
```

The blackout is _not_ attributed to this loop. No amdgpu reset, hung task, watchdog, or OOM evidence
was found for that window. The sustained CPU, Podman, journald, and netns load is a plausible
contributor to the fan behaviour and nothing stronger is claimed.

## Root cause

Commit `293103198` ("Keep every host credential out of the development container") removed the
connector's `TUNNEL_TOKEN` environment entry while leaving `command: tunnel --protocol quic run` and
`restart: unless-stopped` untouched, and replaced the credential with a tmpfs that
`cloudflared tunnel login` was supposed to populate.

```text
TUNNEL_TOKEN removed, command and restart policy unchanged
  -> no tunnel identifier in argv, env, config file, or credential directory
  -> the `${CLOUDFLARED_TOKEN:?}` guard no longer fires, because nothing references it:
     a `:?` guard only protects a variable that is still read
  -> the container is created successfully and cloudflared exits within milliseconds
  -> restart: unless-stopped, to which Podman applies neither backoff nor a retry limit
  -> ~2.8 restarts per second until the host was rebooted
```

The same commit deleted the contract assertion that had pinned `TUNNEL_TOKEN`, so the regression had
no test standing against it.

Compose merge order, variable expansion, and `.env` were all ruled out: `cloudflare-tunnel` is
defined in exactly one file, and no override touches it.

## Two errors in the replacement design

**`cloudflared tunnel login` does not choose what to run.** It writes only the account certificate
`cert.pem`. `tunnel run` needs a tunnel identifier (argv, `TUNNEL_TOKEN`, or a config file `tunnel:`
key) _and_ a per-tunnel credentials file. A fully successful login would still have exited with the
same message.

**A tmpfs made the bootstrap unreachable.** `podman compose exec` needs a running container, but the
container was crash-looping for want of the credential; `podman compose run --rm` discards the tmpfs
with the container that wrote it; and the image is distroless. There was no order of operations that
could have worked.

## Decisions

- The tunnel name is now written into the connector's argv. It is an account-scoped identifier
  rather than a credential, so version control is the right place for it.
- The credential directory moved from tmpfs to the `cloudflared-credentials` named volume. This
  deliberately relaxes `293103198`'s "the credential dies with the container": without it there is
  no reachable login at all. The volume is Podman-managed, so it is still outside the repository
  tree, outside `.env`, and outside every host bind mount, and `podman volume rm` revokes it.
- Two `tunnel-bootstrap` one-shot services perform the login and the credential exchange, because
  the connector cannot do either for itself.
- The connector is behind the `tunnel` profile. A session that needs no edge ingress no longer
  creates it and cannot be affected by its misconfiguration.
- Every `restart: unless-stopped` in the stack became `on-failure:3`. The unbounded policy, not the
  missing identifier, is what turned a configuration mistake into a host incident; `primary`,
  `replica`, `valkey`, and `kafka` carried the same hazard. Note the behavioural trade-off:
  `on-failure` containers are not restarted after a host reboot the way `unless-stopped` ones are.
  `core` keeps `restart: always` because changing it interacts with the Dev Container
  `shutdownAction: stopCompose` lifecycle; that is left for separate work.
- The connector gained `cpus`, `mem_limit`, `pids_limit`, and a size-capped `json-file` log driver.
  No service in the stack had any resource or log bound before this change, and journald enforces no
  per-container size cap.

## Verification

`bin/tunnel-preflight` is new and gates the `up`: it checks that the tunnel is named, that the
external Edge network exists, and that both `cert.pem` and the per-tunnel credentials are in the
volume. It also refuses to run from a linked worktree, because `compose.custom.yaml` pins the
project name while `.env` is untracked and therefore never carried across by `git worktree add` — a
worktree `up` would recreate the primary checkout's containers from an incomplete configuration.

`bin/tunnel-origin-check` now rejects a connector whose `RestartCount` is non-zero and requires
cloudflared's own `/ready` endpoint to answer before probing origins. A container id alone proved
nothing: `ps -q` reports one between restarts.

Superseded on 2026-09-01 as a description of the two scripts named above; the incident, its root
cause, and the compose changes are unaffected.

`bin/tunnel-origin-check` was deleted on 2026-08-30 (`cf448f19e`) and not replaced: `bin/` carries
generated binstubs only. The check it performed survives as a manual host procedure under "Running
the Transport Probe" in `docs/operations/cloudflare-private-origin.md`, including the two gates
described in the paragraph above.

`bin/tunnel-preflight` is not in this repository and, on inspection of every ref, never was. Read
the paragraph describing it as a record of what the session intended rather than of what landed.
`compose.custom.yaml`, which it pinned, has since been retired as well.

See `research/implementation/2026-09-01-bin-custom-script-removal.md`.

Four assertions in `test/unit/security/development_container_contract_test.rb` were confirmed to
fail against the exact pre-fix configuration and to pass after it.

## Not addressed

`podman inspect` on the host emits `Error unmarshalling container ... config: readObjectStart`. It
is unrelated to the immediate failure and is left as a separate candidate. Host-side journald rate
limiting (`RateLimitIntervalSec`, `RateLimitBurst`) is outside this repository but worth confirming.
