# Side Public Host `www-jp` Implementation Notes

## Context

- Request: publish Side's browser-facing origin as `www-jp.umaxica.{app,com,org}` instead of
  `side-jp.umaxica.{app,com,org}`.
- Related: `compose.env` `PUBLIC_SIDE_*_URL`, `lib/config_values_host_family_values.rb`,
  `config/environments/production.rb` Host Authorization.

## Decisions Made During Implementation

- Decision: rename the public Side host family to `www-jp.umaxica.{app,com,org}`. Keep the
  private ingress as the existing `PRIVATE_*` / `*.localhost` names; this change is only the
  Cloudflare-facing `Host`.
  - Why: the operator wants the Side entrypoint reached as the `www-` hyphen-region form, matching
    other regional public names (`palm-jp`, `jp`).
  - Alternatives considered: keep `side-jp` as an additional admitted host. Rejected: two public
    names for the same Side family.
- Decision: move empty-ENV Base development fallbacks from `www-jp.umaxica.*` to `www.umaxica.*`.
  - Why: Base's published `PUBLIC_BASE_*` values were already `www.umaxica.*`. Leaving Base's
    fallback on `www-jp` would collide with Side after this rename when ENV is empty.
  - Follow-up needed: Cloudflare Tunnel public hostnames and Access applications must publish
    `www-jp.umaxica.{app,com,org}` (not `side-jp`) to the same origin as today's Side ingress.
    Ingress is remotely managed; this repository does not contain those rules.

## Deviations From Plan

- Change: hostnames live in `compose.env` (and env examples), not `compose.yaml`.
  - Why: `compose.yaml` has no Side public hostname entries; Compose injects `PUBLIC_SIDE_*` from
    `compose.env`.
  - Risk: operators looking only at `compose.yaml` will not see the rename.

## Review Notes

- Tests run: `bin/rails test test/lib/config_values/host_family_values_test.rb
  test/config/host_authorization_contract_test.rb`. Host Family passed. Host Authorization
  failed until `.devcontainer/compose.yaml` frontend aliases replace `side-jp.umaxica.*`
  with `www-jp.umaxica.*`. That file is mounted read-only in this workspace
  (`tank/Projects on .../.devcontainer type zfs (ro,...)`), so the alias rename is blocked
  here.
- Tests not run: full suite; Cloudflare dashboard verification (out of repo).
- Documentation promotion needed: operations docs that still quote `side-jp` as the live public
  name should follow once the tunnel hostname is cut over.
