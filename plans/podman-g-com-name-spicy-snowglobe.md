# Fix: podman devcontainer "core" stops on `EMAIL_ADDRESS_HMAC_SALT` KeyError

## Context

The `global-devcontainer-core` podman container appears to "crash" on startup. It doesn't — podman
itself is healthy. The actual sequence, confirmed from container logs and source:

1. `bin/dev` runs `db:prepare`, which runs migrations then `db/seeds.rb`.
2. `db/seeds.rb:40-43` / `:59-62` `save!` a `ClientEmail`/`OperatorEmail` record.
3. The `Email` concern's `before_validation :set_address_digests` callback
   (`app/models/concerns/email.rb:44,98-102`) unconditionally calls
   `IdentifierBlindIndex.bidx_for_email` (`app/models/concerns/email.rb:99`).
4. `IdentifierBlindIndex.secret_credential_for_email` →
   `required_secret_credential(:EMAIL_ADDRESS_HMAC_SALT)`
   (`app/services/identifier_blind_index.rb:17-55`) checks Rails encrypted credentials first, then
   falls back to `ENV.fetch("EMAIL_ADDRESS_HMAC_SALT")`. Both are empty, so it raises
   `KeyError: Missing key: [:EMAIL_ADDRESS_HMAC_SALT]`.
5. `bin/rails db:prepare` aborts non-zero.
6. `.devcontainer/tailscale-core-supervisor.sh`'s supervisor loop (lines ~174-184) detects the
   workload process exited non-zero, logs
   `"development workload exited with status ...; stopping Tailscale"`, stops tailscaled, and
   **exits the supervisor itself with that status** — since the supervisor is the container's
   foreground process, this stops the whole container. This behavior is correct/by-design (fail the
   container when the dev workload fails); it is not the bug.

Root cause: `compose.yaml`'s `core.environment` block defines dozens of vars (Postgres, Redis,
object storage, public/private URLs, etc.) but never lists `EMAIL_ADDRESS_HMAC_SALT` or its sibling
`TELEPHONE_NUMBER_HMAC_SALT`, so neither reaches the container even if set in the developer's local
`.env`. This is a pre-existing config gap, unrelated to the currently in-progress, uncommitted
Tailscale SSH/login-shell changes (`entrypoint.sh`, `tailscale-core-supervisor.sh`,
`tailscale-core-login-environment.sh`) — those diffs don't touch env wiring for `bin/dev`.

### Decision: fixed dev-only value directly in `compose.yaml`, not sourced from `.env`

The user's explicit direction: `.env` is planned for eventual removal, and a random per-machine salt
is not wanted here. Instead, put a fixed, arbitrary placeholder value straight into `compose.yaml`
for local development, matching the existing precedent already in this file for
`POSTGRESQL_PASSWORD` / `POSTGRESQL_USER` / `POSTGRESQL_DATABASE` (checked-in dev defaults via the
`${VAR:-default}` interpolation form). This value is understood to be a local-development-only
placeholder that will differ from whatever value production/staging uses, so it is fine for it to be
public/checked into the repo.

## Change

In `compose.yaml`, under `services.core.environment`, add a new group near the other credential
entries (e.g. after the PostgreSQL credentials block):

```yaml
# --- Identifier HMAC salts (dev-only fixed values; differ from production) ---
EMAIL_ADDRESS_HMAC_SALT: "${EMAIL_ADDRESS_HMAC_SALT:-development_email_address_hmac_salt}"
TELEPHONE_NUMBER_HMAC_SALT: "${TELEPHONE_NUMBER_HMAC_SALT:-development_telephone_number_hmac_salt}"
```

This still allows a developer to override via `.env` if they want, but boots successfully with no
`.env` entry at all, using the fixed placeholder — consistent with how `POSTGRESQL_PASSWORD` already
defaults to `development_password` in this same file.

## Verification

1. `grep -n "HMAC_SALT" compose.yaml` shows both new entries.
2. Restart the devcontainer (`podman compose up -d --force-recreate core` or the project's usual
   restart command) and confirm `bin/dev`'s `db:prepare`/seed step completes without the `KeyError`,
   and the container stays up.
3. Confirm this works with no `EMAIL_ADDRESS_HMAC_SALT`/`TELEPHONE_NUMBER_HMAC_SALT` set in `.env`
   at all (the whole point is to not depend on `.env` for this).
