# Development Credential Provisioning

No credential material is tracked in this repository. The encrypted Rails credential payloads
(`config/credentials/*.yml.enc`) are committed, but the keys that decrypt them are not, and neither
is the repository-root `.env`. A fresh clone therefore cannot boot the application or run the test
suite until the missing pieces are supplied out of band. This document lists what is missing, where
each item belongs, and who issues it.

## What is not in git

| Item              | Location              | Ignore rule in `.gitignore` |
| :---------------- | :-------------------- | :-------------------------- |
| `development.key` | `config/credentials/` | `/config/credentials/*.key` |
| `test.key`        | `config/credentials/` | `/config/credentials/*.key` |
| `.env`            | repository root       | `.env`                      |
| `.secrets/`       | repository root       | `.secrets/`                 |

`.secrets/` is not written by anything in this repository. Development service passwords are fixed
literals declared inline in `compose.yaml`, as described below, and the Podman Secret machinery that
once populated this directory was removed with the script that registered it. One optional workflow
still reads a file there, created by hand: `docs/operations/remote-codex-over-tailscale.md`. The
ignore rules stay so that a directory created that way, or left over from an earlier checkout, can
never enter a commit or a build context.

`config/credentials/development.yml.enc` and `config/credentials/test.yml.enc` are tracked, and are
unreadable without the matching `.key` file. Committing a `.key` file defeats the encryption of the
payload it unlocks, so no key file may ever enter a commit, a branch, an issue, or a pull request.

## Rails credential keys

Two key files are required for local work:

- `config/credentials/development.key` — needed to boot the application.
- `config/credentials/test.key` — needed to run `bin/rails test`.

**Obtain both from the development lead** (the Tech Lead / Architect role defined in `docs/srs.md`).
They are shared over an encrypted channel and are never sent by plain email or chat.

Do not generate these keys locally. `bin/rails credentials:edit` creates a new key when none is
present, which silently replaces the key for the committed `.yml.enc` payload and makes that payload
undecryptable for everyone else. If decryption fails, request the correct key rather than
regenerating one.

Place each file at its exact path under `config/credentials/` and restrict its mode:

```bash
chmod 600 config/credentials/development.key config/credentials/test.key
```

Rails reads only `config/credentials/<environment>.key`. A copy at the repository root has no effect
and is not covered by the `config`-scoped ignore rules, so it is a leak risk with no benefit.

Verify the keys work without printing secret values to a shared terminal:

```bash
bin/rails credentials:show --environment development
bin/rails credentials:show --environment test
```

A missing or wrong key surfaces as `ActiveSupport::MessageEncryptor::InvalidMessage` during boot or
during a test run. That error means the key does not match the payload; it does not mean the
committed payload is corrupt.

CI does not use these files. GitHub Actions supplies the key through the `RAILS_MASTER_KEY` secret
(`.github/workflows/ci.yml`).

## Repository-root `.env`

Compose reads the repository-root `.env`. It currently carries four settings:

| Key                      | Source                                        |
| :----------------------- | :-------------------------------------------- |
| `UID`                    | written by hand: your host `id -u`            |
| `GID`                    | written by hand: your host `id -g`            |
| `CLOUDFLARED_TOKEN`      | Cloudflare dashboard, or the development lead |
| `CLOUDFLARED_EDGE_TOKEN` | Cloudflare dashboard, or the development lead |

`UID` and `GID` feed the `DOCKER_UID`/`DOCKER_GID` build args, which decide the workload UID baked
into the `core` image. `$UID`/`$GID` are bash builtins rather than exported variables, so Compose
never sees them from the environment; write them into `.env` once per machine:

```bash
printf 'UID=%s\nGID=%s\n' "$(id -u)" "$(id -g)" >> .env
```

Appending is safe as long as no earlier `UID=`/`GID=` line exists — Compose takes the last
occurrence, but a duplicate is confusing to read. Leaving them out is not silent: Compose falls back
to `1000`, and on a host whose user is not `1000:1000` every bind-mounted repository file appears
with the wrong owner inside the container.

Both `CLOUDFLARED_TOKEN` and `CLOUDFLARED_EDGE_TOKEN` are tunnel-scoped: the account holds two
development tunnels and each variable authorizes a connector for one of them, started by the
`tunnel` and `tunnel-edge` profiles respectively. Retrieve them yourself from the Cloudflare
dashboard following `docs/operations/cloudflare-private-origin.md`; **request them from the
development lead when you do not have dashboard access.** Only the tunnel you actually start needs a
token; a connector started without one exits immediately and stays stopped after three bounded
restart attempts. There is no anonymous fallback.

The committed `.env.example` and `.env.devcontainer.example` files are non-secret development
contracts only. They contain obvious local placeholders, never provider credentials or Rails keys.
Copy `.env.example` to the ignored `.env` only when host-specific overrides are needed:

```bash
cp .env.example .env
chmod 600 .env
```

## Provider credentials for staging, production, and individual environments

This covers AWS, Cloudflare, Fastly, and every other content-delivery or infrastructure provider.

No staging or production provider credential is stored in this repository in any form, encrypted or
otherwise, and none is issued self-service. The same applies to credentials scoped to one
developer's own environment.

**Request them from the development lead.** State:

- the provider and the account or zone involved,
- the environment (staging, production, or a named individual environment),
- the scope or permissions required,
- what the credential is for and how long it is needed.

The development lead either issues a scoped credential or performs the operation on the requester's
behalf. Broad or long-lived credentials are not issued for convenience.

A credential you receive stays out of the repository. Put it in the gitignored `.env`, in Rails
encrypted credentials, or in the provider's own secret store. Never place it in a tracked file, a
Compose file, a container image, a plan under `plans/`, or a note under `research/`. When a
credential is no longer needed, or may have been exposed, tell the development lead so it can be
revoked.

## Development service passwords: fixed literals

The development PostgreSQL passwords are fixed, development-only values represented in the local
environment contract and consumed by the infrastructure services. They are not generated, not
rotated, and not secret:

| Variable                        | Value         | Set on                 |
| :------------------------------ | :------------ | :--------------------- |
| `POSTGRESQL_PASSWORD`           | `development` | `.env.example`, `core` |
| `POSTGRES_PASSWORD`             | `development` | `primary`, `replica`   |
| `POSTGRES_REPLICATION_PASSWORD` | `replication` | `primary`, `replica`   |

This is deliberate. The stack is development-only, every database it serves is disposable, no port
is published for `primary` or `replica`, and the values guard nothing reachable off the host. A
value the whole team can read in the file it is written in is worth more here than a random one
nobody can look up. Production credentials are unaffected and continue to come from Rails encrypted
credentials and the provider's own secret store, as described above.

Keep the three `core` values identical to the `primary` and `replica` values. PostgreSQL bakes the
password into `primary-data` at initdb time, so changing a literal without also removing the
`primary-data` and `replica-data` volumes locks the stack out of its own database. Recreate both
volumes together after any change.

There is no host-side secret bootstrap command or credential volume. A fresh clone needs the tracked
non-secret environment contract and Rails credential keys; provider credentials remain out of band.

## GitHub authentication inside the development container

**No host credential is passed into the container.** Not a private key, not the ssh-agent socket,
not `~/.config/gh`, not a token. Nothing in this repository binds a host credential path into
`core`, and no environment variable carries one.

Every tool authenticates inside the running container through its own browser login, and the result
is discarded when the container is recreated:

```bash
gh auth login --web --git-protocol https && gh auth setup-git
claude   # then /login
codex login
```

**Remotes must be HTTPS.** `git@github.com` does not work inside the container, by design;
`gh auth setup-git` wires the credential helper so `git fetch` and `git push` work over HTTPS.

### What was removed, and why

Two arrangements were tried and withdrawn.

**The host ssh-agent socket** was bind-mounted at `/ssh-agent`, with `~/.ssh/known_hosts` bound
read-only. The private key never crossed the boundary, which is true but not sufficient: anything
running inside the container -- a build script, a dependency's install hook, an agent acting on the
repository -- could ask the socket to sign with **every key the agent holds**, for as long as the
container lived, with no per-use confirmation and no record on the host of what was signed. The
socket is a signing oracle; forwarding it grants use of the key even though it withholds the key.

**`GH_TOKEN`** was forwarded from the host as the replacement. It was then removed too, because
`gh auth login` run inside the container works: a host token bought nothing that the in-container
browser login does not, while adding a credential that outlives any single container and has to be
exported into every shell that starts Compose.

Do not reintroduce either. If a workflow genuinely needs SSH to GitHub, run it on the host.

### Two limits on the "no host credential" claim

State them plainly rather than reading the claim more broadly than it holds.

1. **Dev Container Features can declare their own `mounts`.** Those do not appear in
   `devcontainer.json` or in any compose file, so auditing this repository alone is not sufficient.
   Read each Feature's `devcontainer-feature.json` before adding it, and prefer Features that
   authenticate in-container over Features that bind a host state directory.

   One Feature in use does exactly that, and it is accepted knowingly.
   `ghcr.io/sliekens/devcontainer-features/grok-build` declares

   ```
   ${localEnv:HOME}/.grok/  ->  /var/lib/grok-build   (read-write)
   ```

   and its `onCreateCommand` symlinks the container's `~/.grok` to that target, so the host's
   `auth.json`, sessions, and configuration are live-writable from inside the container. The Feature
   exposes only `version` and `channel`; there is no option to disable the mount, and every project
   using the Feature shares the one host directory. Anything running in the container can read and
   rewrite the host Grok credentials.

   This is retained for the convenience of surviving a rebuild without re-authenticating. To remove
   it, drop the Feature and run the upstream installer from `postCreateCommand`
   (`curl -fsSL https://x.ai/cli/install.sh | sh`), then `grok login` inside the container. The MCS
   level pinned in `.devcontainer/compose.yaml` exists for this mount; remove them together.

   The other three Features -- `github-cli`, `anthropics/claude-code`, and `nolanjx/codex` --
   declare no `mounts`. That was verified by reading each cached `devcontainer-feature.json`, not
   assumed.

2. **The workspace bind mount carries whatever the repository holds.** That includes the gitignored
   `.env` (`CLOUDFLARED_TOKEN`) and `config/credentials/*.key`. Those files are readable inside
   `core`. What the claim above means precisely is that no _host-owned_ credential outside the
   repository is handed over, and that `CLOUDFLARED_TOKEN` reaches only the separate
   `cloudflare-tunnel` sidecar as an environment variable.

### Verification

Inside the container:

```bash
gh auth status             # reports a token from the in-container login, not the environment
git fetch                  # HTTPS via the gh credential helper
gh repo view
```

## Related documents

- `docs/operations/cloudflare-private-origin.md` — obtaining and placing `CLOUDFLARED_TOKEN`.
- `docs/operations/development-container-targets.md` — bringing up the development containers.
- `docs/operations/container-engine-podman-notes.md` — rootless Podman and SELinux behaviour.
- `docs/hld.md` — the environment-variable catalog and the `.env` boundary.
- `docs/reference/repository-language-policy.md` — language rules for repository prose.
