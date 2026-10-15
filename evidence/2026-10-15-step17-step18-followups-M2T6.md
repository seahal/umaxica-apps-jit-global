# Step 8, 9, 17 and 18 follow-ups

- Base commit: `9f407d7015dd487225ad5dd6120e70760ff2fdc4` on `feature`. The changes below were
  verified as uncommitted edits on top of it and committed immediately afterwards. Actor: Claude
  Opus 5.5 (claude-opus-5-5).
- Databases: standard Rails test database only. `POSTGRESQL_ISOLATED_TEST_RUN_ID` was unset.

## Step 17 — AV-5 / AT-071 HTTP replay

AV-5 was already PASS for the authority matrix
(`evidence/2026-10-13-avatar-step17-http-authority-followup-C8M2.md`). That run did not exercise
AT-071's replay clauses over HTTP. Added cases:

- APP: the same `Idempotency-Key` with a different target collective returns 422, creates no
  reservation, and leaves the recorded reservation's attributes unchanged.
- APP: the same key from a different Client returns 422, with the same no-change assertions.
- APP and ORG: a keyless (legacy) request after the cutover marker returns 422 with "legacy Avatar
  transfer operations are unavailable after cutover" and creates no transfer or reservation.

`bin/rails test` on both transfer controller files: 33 runs, 167 assertions, 0 failures, 0 errors.
RuboCop: no offenses. No application code changed. Still not covered: ORG different-input and
different-initiator replay, and the "committed success discoverable after a lost response" clause,
which is covered at the operation level only. AV-3/AV-6 and MIG-2/MIG-4 remain BLOCKED (no isolated
fleet).

## Step 8 — REQ-039 detection

- `bundle exec rubocop -c .rubocop_frozen_string_literal.yml --only Style/FrozenStringLiteralComment,Style/DisableCopsWithinSourceCodeDirective`
  (the `config/ci.rb` invocation) on throwaway fixtures detected all four required cases: missing
  comment, `false`, comment after code (reported as missing), and an inline disable (reported by
  `DisableCopsWithinSourceCodeDirective`). A correct file passed.
- The same invocation on the repository reports 10 offenses, all in read-only `bin/`.
  `ruby scripts/check_frozen_string_literal_directives.rb` lists the same 10 files. The cop's file
  list includes `config.ru`, migrations and `bin/`.
- Finding: without `--only`, the scoped config also reports Metrics offenses. Under
  `DisabledByDefault`, inline `rubocop:enable` directives reactivate those cops, and disabling the
  departments in the config did not prevent it (tried, then reverted). The `--only` flag is
  therefore required. `config/ci.rb` has it. The GitHub Actions job does not run this check, and
  `.github/` is read-only.
- Not done: migration replay (needs the isolated fleet); `bin/` directives (read-only mount).

## Step 9 — REQ-029 production output: BLOCKED

`RAILS_ENV=production bin/rails runner` was attempted with `TRUSTED_PROXIES=127.0.0.1/32`,
`SECRET_KEY_BASE_DUMMY=1` and `.invalid` hosts or closed loopback `rediss://127.0.0.1:1` values for
the keys that boot required in turn: `BASE_*/PALM/HELP_*/INFO_*` service URLs,
`CACHE/RATE_LIMIT/AUTH_STATE_REDIS_URL`, and throwaway P-384 JWK sets for `AUTH_JWT_PUBLIC_KEYSET`
and `PREFERENCE_JWT_PUBLIC_KEYSET`. Boot then stopped on `OIDC_CLIENT_BASE_RP_APP_WW_ACTIVE_KID` /
`_PRIVATE_KEY`, the first of the per-client private keys. Fabricating a full production key set was
judged not to be an observation of production behavior, so the attempt stopped there. No database or
network target was contacted (the application never finished booting), and the throwaway keys were
deleted.

## Step 18 — documents

Updated `docs/checklists/avatar-ownership.md` (AV-5) and
`plans/backlog/avatar-ownership-acceptance-followups.md`. The logout docs and ADR were updated with
Step 6. `one.md`/`two.md` are unchanged per CHG-008.
