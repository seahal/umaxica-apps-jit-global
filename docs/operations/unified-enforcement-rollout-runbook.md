# Unified Enforcement Rollout Runbook

This is the step-by-step operational companion to `adr/unified-enforcement.md` (design and Decision
Log) and `docs/security/unified-enforcement.md` (operational contract). Read those first for
rationale; this document only covers deployment mechanics, provisioning order, and verification
steps.

## Current status

Phases 0 through 10 are implemented, tested, and merged to `develop`. Phase 11 (parity, rollout,
documentation) is partially done:

- Signup gating (email + telephone, `app` and `com`) is wired and tested.
- Identifier attachment gating (email + telephone, `app`/`com`/`org`) is wired and tested.
- The org console (Phase 9: create/approve/release, realm-scoped) is wired and tested.
- Recovery flow gating has no wiring target: this repository has no account-recovery or reactivation
  controller today. `EnforcementIdentifierGate#enforcement_blocks_email_recovery?` and
  `#enforcement_blocks_telephone_recovery?` exist and are unit-tested for when such a controller is
  built; wiring them in without a recovery flow to attach to would be scope invention, not rollout.
- Production secret provisioning (below) has not been performed outside `compose.yaml`'s
  development-only defaults.

## Secret provisioning order

Three secrets gate all live enforcement paths:

- `ENFORCEMENT_APP_IDENTIFIER_HMAC_KEY`
- `ENFORCEMENT_COM_IDENTIFIER_HMAC_KEY`
- `ENFORCEMENT_ORG_IDENTIFIER_HMAC_KEY`

Each is read by `EnforcementIdentifierDigest.key_for(realm)`
(`app/services/enforcement_identifier_digest.rb`), which checks `Rails.app.creds` (encrypted
credentials, then ENV) and raises `KeyError` — by design, per
`.agents/harnesses/rules/generic/no-silent-fallback.mdc` — if the realm's key is absent. This is
fail-closed: an unprovisioned key does not silently disable enforcement, it 500s the request path
that needed it.

**Provisioning must happen before any Phase 11 code that reads these keys reaches an environment**,
for every environment in turn (never all at once, and never after deploying the code):

1. Generate three independent, high-entropy secrets (do not reuse `EMAIL_ADDRESS_HMAC_SALT` /
   `TELEPHONE_NUMBER_HMAC_SALT`, or any secret across realms — D6 requires per-realm, dedicated keys
   so a compromised login-lookup key cannot double as an offline oracle over the enforcement list,
   and vice versa).
2. Add them to the target environment's actual secret store (Rails encrypted credentials or the real
   ENV injection mechanism for that environment — for this repository's dev containers, that is
   `compose.yaml`'s `environment:` block, already updated with development-only defaults; production
   has its own separate mechanism outside this repository's checked-in files).
3. Restart/redeploy so every app process picks up the new value. Confirm with a Rails console in
   that environment: `EnforcementIdentifierDigest.key_for("app")` (repeat per realm) must return a
   non-nil string, not raise.
4. Only after all three keys are confirmed present in an environment, deploy application code that
   calls `EnforcementIdentifierDigest`/`EnforcementIdentifierGate` to that environment.

Deploying the gating code before the keys exist in that environment reproduces the exact failure
already caught once during Phase 6/11 development: every signup, attachment, and future recovery
request that reaches the gate raises `KeyError` and 500s.

## Migration order

Apply per-realm `*_zenith_migrate` migrations (Phases 2, 6, 7) before `*_ticket_migrate` and
`chronicle_migrate` migrations (Phases 1a, 3) only matter relative to each other, not to the zenith
migrations — there is no cross-database FK (D7), so no database's migration is blocked on another's.
`db:migrate` run against a fresh environment in any order converges; there is no manual sequencing
step required beyond the standard `bin/rails db:migrate` per configured role, which this
repository's `db:test:prepare` override already demonstrates for the test environment.

Trigger migrations (Phase 8, D20) are scoped to specific tables. Do not migrate a
`permanently_frozen`-capable trigger onto `client_google_identities`, `client_apple_identities`, or
`client_external_identities` — D20 explicitly defers those until the common-storage cutover
(`ExternalAuthentication::IdentityRepositoryFactory.common_storage?`) is complete everywhere. A
CHECK constraint already prevents `permanently_frozen` on `google`/`apple` Method Effects
independent of trigger presence, so this is a defense-in-depth ordering note, not a hard blocker.

## Verification checklist per environment

Run after secret provisioning and migration, before considering that environment live:

1. `EnforcementIdentifierDigest.key_for(realm)` returns non-nil for `app`, `com`, `org`.
2. `bin/rails db:migrate:status` shows zero pending migrations across all 19 database roles.
3. Full regression suite green in that environment's CI, including
   `test/controllers/base/org/support/enforcement_cases_controller_test.rb` (org console),
   `test/integration/enforcement_identifier_attachment_gate_test.rb` (attachment gating),
   `test/services/enforcement_identifier_digest_test.rb`, and
   `test/controllers/concerns/enforcement_identifier_gate_test.rb`.
4. `test/models/enforcement_triggers_test.rb` passes (confirms both currently-built triggers —
   `client_emails` permanently_frozen protection, `clients` hard-delete protection — reject the
   raw-SQL/`delete_all` paths they guard).
5. Recurring jobs `EnforcementExpiryJob` and `EnforcementReconciliationJob` are present in
   `config/recurring.yml` for that environment and the scheduler is actually running them (check the
   job runner's own operational dashboard, not just the YAML).
6. A smoke test through the org console: create a `cooldown` Case with no approval required, confirm
   it applies immediately; create a `permanent_ban` Case, confirm it requires approval and does not
   apply until a second operator approves.

## Known remaining scope (not blocking this rollout, tracked for later work)

- No Google/Apple Identifier Effect trigger (D20, deferred to post-cutover).
- No fine-grained realm-scoped permission grant matrix for operators (D13) — `EnforcementCasePolicy`
  currently authorizes on `Operator` alone, with no per-realm grant distinction, because this
  repository has no existing operator RBAC system to extend.
- 14 of the ~16 planned per-table triggers remain unbuilt (Phase 8 note in the plan's Progress Log):
  `*_telephones`, `*_passkeys`, `*_secret_credentials` across all three realms,
  `client_totp_credentials`, `operator_entra_identities`, and hard-delete protection on `visitors`
  and `operators`. Each follows the exact pattern already proven on `client_emails` and `clients`
  (use `clock_timestamp()`, never `now()`, in any time-predicate trigger; test raw-SQL failure paths
  on the connection that owns the table, not `ActiveRecord::Base.transaction`).
- No account-recovery or reactivation controller exists in this codebase at all today, so
  `recovery_blocked` and `reactivation_blocked` Principal/Identifier Effect gates have no live call
  site. Building such a controller is out of scope for the enforcement rollout itself.
- Production secret provisioning (the store update in step 2 above) is an infrastructure action
  outside this repository's checked-in files and outside the scope any single code change can
  perform; it is a manual operational step for whoever owns each environment's secret store.
