# Plan: `compose.custom.yaml` — always-on Tailscale/cloudflared/admin-GUI overlay

## Context

Yesterday's Phase B work (see
`plans/project-umaxica-linux-host-data-platform-and-network-sidecar-audit.md` §19.5/§23) put
`cloudflare-tunnel` and `tailscale-codex` behind opt-in Compose profiles
(`tunnel`/`tailscale`/`remote`), so a plain `devcontainer up` starts neither. In practice this means
every dev session that wants either sidecar requires remembering an extra `--profile` flag on top of
`devcontainer up`, which the devcontainer CLI itself cannot pass through today (no `runServices`
support for profiled services, and a documented VS Code/devcontainer-CLI compatibility gap between
Compose v2 profiles and dev containers).

The user wants a third Compose file, `compose.custom.yaml`, that both sidecars (plus the existing
`pgadmin`/`tinyrdm` admin GUIs, currently gated behind a separate `tools` profile) move into, with
**no profile gating at all** — the file's inclusion in the merged Compose invocation is itself the
on/off switch. `devcontainer.json` will reference this file unconditionally, so a normal
`devcontainer up` starts everything, including cloudflared and Tailscale, with no extra flags.

**Explicit, already-confirmed trade-off:** this reverses the "ask before external communication"
boundary set earlier for Tailscale specifically — after this change, every ordinary
`devcontainer up` will attempt real tailnet registration automatically, with no per-session
confirmation. The user was asked directly and confirmed this is intended
("はい、完全撤廃でよい(要求通り)").

Decisions from the review round (all confirmed by the user, not to be re-litigated):

1. **`compose.custom.yaml` is a committed, git-tracked file** — not gitignored, not a `.example`
   template. It is shared, deterministic infrastructure config.
2. **Credentials move into the project's existing `.env`** (already gitignored, already the
   established secret-loading convention — see `CLOUDFLARED_TOKEN` in current `compose.yaml`),
   loaded via Compose's built-in `.env` variable-substitution plus an explicit `environment:` entry
   (same pattern `cloudflare-tunnel` already uses for `TUNNEL_TOKEN: "${CLOUDFLARED_TOKEN}"`). This
   replaces `tailscale-codex`'s current `env_file: ["${HOME}/.config/umaxica/tailscale.env"]`
   external-host-path mechanism.
3. **Profiles removed entirely** for `cloudflare-tunnel`, `tailscale-codex`, `pgadmin`, `tinyrdm` —
   their mere presence in `compose.custom.yaml` is the opt-in.
4. **Scope includes `pgadmin`/`tinyrdm`** (not just the two sidecars) — user explicitly asked to
   fold these in too.
5. **`devcontainer.json` requires the file unconditionally** — if it's ever missing,
   `devcontainer up` should fail loudly rather than silently degrade. Since the file is committed
   (decision 1), it will never actually be missing on any checkout, so this requirement is satisfied
   for free — no bootstrap/copy step needed.

## Approach

### File-by-file changes

**`compose.yaml`** (base, shared): remove the `cloudflare-tunnel` service block entirely. Update the
stale `networks:`/`volumes:` section comments (currently document only the
`tailscale-codex`/`remote-access` exclusion) to also note `cloudflare-tunnel` now lives in
`compose.custom.yaml`. Do not touch the `frontend` network definition — it's shared infrastructure
other services still use.

**`.devcontainer/compose.override.yml`** (devcontainer-shared, committed): remove the
`tailscale-codex` service block, the `remote-access` top-level network entry, the
`tailscale-codex-state` volume entry, and the `pgadmin`/`tinyrdm` service blocks (including their
`tools` profile and host port publishing). Keep `remote-sshd` volume and everything else in `core`'s
override stanza unchanged (build args, `userns_mode`, mounts, ports, `REMOTE_SSHD=1`, etc. — these
are devcontainer-shape requirements, not personal/optional, per the confirmed narrow scope).
**Important coupling:** `core`'s current override includes `networks: remote-access: {}` so it's
reachable from `tailscale-codex` — since `remote-access` now only exists when `compose.custom.yaml`
is loaded, this attachment must move into `compose.custom.yaml` as an additional `core:`
service-merge fragment (Compose merges same-named services across files field-by-field; this is
normal and safe), not stay behind in the override file where it would otherwise reference an
undefined network.

**New `compose.custom.yaml`** (repo root, **committed**): contains, all without any `profiles:` key:

- `cloudflare-tunnel` — moved from `compose.yaml`, unchanged in every other respect (image,
  `depends_on: [core]`, `command`, `TUNNEL_TOKEN: "${CLOUDFLARED_TOKEN}"`, `networks: [frontend]`,
  `extra_hosts`, `restart: unless-stopped`).
- `tailscale-codex` — moved from `.devcontainer/compose.override.yml`, with its credential source
  changed: replace `env_file: ["${HOME:?HOME must be set}/.config/umaxica/tailscale.env"]` with
  `environment: TS_AUTHKEY: "${TS_AUTHKEY:?TS_AUTHKEY must be set in .env}"` (and keep the other
  existing `TS_*` environment entries as-is). Everything else (volumes, networks, `restart`)
  unchanged.
- `pgadmin` and `tinyrdm` — moved from `.devcontainer/compose.override.yml` verbatim minus the
  `profiles: [tools]` key; host port publishing (5050:80, 8086:8086) stays.
- `core:` — a small fragment adding `networks: remote-access: {}` (the coupling noted above).
- Top-level `networks: remote-access: {}` and `volumes: tailscale-codex-state: {}`.

**`.env.example`**: add a `TS_AUTHKEY=` entry (with a short comment on how to obtain a tagged,
pre-authorized Tailscale auth key) alongside the existing `CLOUDFLARED_TOKEN`-style entries, so the
new credential-sourcing convention is discoverable. **Constraint to verify at implementation time:**
`.env`/`.env.example` were not readable by this agent during planning (tool-level permission denial,
independent of plan-mode) — confirm at implementation time whether Edit/Write access to
`.env.example` is available; if not, this step may need to be done by the user directly, or the
permission may need to be granted first.

**`.devcontainer/devcontainer.json`**: change `dockerComposeFile` from
`["../compose.yaml", "./compose.override.yml"]` to
`["../compose.yaml", "./compose.override.yml", "../compose.custom.yaml"]`.

### Documentation follow-ups (part of this change, not deferred)

- `docs/operations/remote-codex-over-tailscale.md`: update the credential-sourcing description
  (external `~/.config/umaxica/tailscale.env` → project `.env`'s `TS_AUTHKEY`), and revert
  yesterday's `--profile tailscale` command-example edits back to no-profile-flag invocations that
  include all three `-f` files (profiles no longer exist on this service).
- `docs/operations/cloudflare-private-origin.md`: check for any profile-flag references that need
  the same treatment.
- `plans/project-umaxica-linux-host-data-platform-and-network-sidecar-audit.md`: §19.5's decision
  record and §23's Phase B result describe the now-superseded profile-gated design. Add a short
  dated addendum noting this was revised (do not silently rewrite history — note the change and
  why).

## Verification (read-only, no `up`, no tailnet registration)

Same pattern already validated successfully in this session — `config`-only renders, never
`up`/`pull`/`start`:

1. `podman compose -f compose.yaml config --services` — confirms `cloudflare-tunnel` no longer
   appears, no dangling references.
2. `podman compose -f compose.yaml -f .devcontainer/compose.override.yml config --services` —
   confirms this two-file combination still resolves cleanly (no more `remote-access`/
   `tailscale-codex-state`/`pgadmin`/`tinyrdm` references left behind in the override).
3. `podman compose -f compose.yaml -f .devcontainer/compose.override.yml -f compose.custom.yaml config --services`
   — confirms `cloudflare-tunnel`, `tailscale-codex`, `pgadmin`, `tinyrdm` all appear with **no
   `--profile` flag needed**, and that `core`'s merged config shows `remote-access` attached.
4. Full `config` (no `--services`) render, visually checked for duplicate/conflicting top-level
   `networks:`/`volumes:` definitions across the three files.
5. `python3 -c "import yaml; yaml.safe_load(open('compose.custom.yaml'))"` (or equivalent) for basic
   YAML syntax validation.

No `podman compose ... up`, `... pull`, or `devcontainer up` is run as part of this implementation —
starting `tailscale-codex` for real (the actual tailnet registration) stays a separate,
explicitly-confirmed step, same as established earlier this session.

## Rollback

Standard `git revert` of the implementing commit(s) restores the prior two-file, profile-gated shape
exactly — `compose.custom.yaml` is committed (decision 1), so unlike the earlier `.example`-template
design, there is no host-only leftover file to separately clean up after a revert.
