# app Secret retirement and login inventory

Executed on 2026-10-04 UTC; final observation at 01:25 UTC. Rails feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with concurrent uncommitted changes
(226 paths before adding this record). Only the guarded
`codex_integrity_20261003secret_*` disposable fleet was used.

## Implemented and observed

ClientSecretRevocationCommitter is a draft public management operation. It validates
Base app actor/session types, locks Client before the current Ticket Token and
credential, and rereads ownership, account availability, session usability and
existing operation-specific Step-Up. Secret cannot satisfy that Step-Up. The
existing last-login-method guard remains. Only an available confirmed unclaimed
credential can enter a new management retirement transition.

Revocation, discard and source audit commit on Zenith. Two immutable events,
secret.revoked and secret.discarded, share an operation reference and writer time;
the actor is derived from the existing authenticated Client context. No name,
Secret, digest or browser credential enters either event. Ticket is read/locked,
not mutated, and no distributed transaction is assumed. The operation preserves
the current session, including a fixture session attributed to Secret login.

The explicit caller duration sets physical eligibility, not Secret validity. No
production duration was chosen. Tested -1 second, zero, the nearest PostgreSQL
timestamp increment above zero (one microsecond), type sentinels and infinity.
Initial Float-duration addition collapsed one microsecond when persisted; rounding
to the existing timestamp(6) precision fixes that observed boundary. A duration
that cannot advance the stored timestamp is rejected. Existing Retainable#lapsed?
handles infinity without comparing a Float directly with Time.

Repeating the operation creates no more audit and does not extend retention.
Missing/expired/mismatched Step-Up, revoked/restricted/expired session, wrong owner,
wrong surface, anonymous/absent bindings and pending/claimed/discarded credentials
are refused. An invalid second audit event rolls back both events and lifecycle
mutation. The test substitutes UUID generation, not the recorder or its success.

AuthenticationCredentialInventory now counts available app Secrets for ordinary
login and exclusion/removal checks, using writer facts. It does not add Secret to
Step-Up, contact or com/org credential inventory. Replaced the old app Emergency
inventory expectation and its old owner cleanup with the approved normal-login
contract. Contact-free confirmed Secret inventory is tested.

## Actual verification

All Ruby commands used `bundle exec ruby /tmp/umaxica-secret-db-task.rb test`.

- Initial new retirement tests: 6 tests, 1 assertion, 1 failure and 5 errors because
  the requested operation did not yet exist. The database setup completed; this
  was missing implementation, not an environment failure.
- Contact-free normal Secret inventory Red: 16 tests, 21 assertions, one failure
  (expected [:secret], actual []), no errors/skips.
- Earlier expanded selection: 60 tests, 403 assertions, 16 errors from old
  `ClientSecretCredential.where(user: ...)` cleanup, no assertion failures/skips.
  Corrected that ownership reference and replaced the obsolete Emergency case.
- Final selection: retirement/name operations; source outbox and rebuilt credential
  models; capacity/lookup queries; Secret ownership and AuthMethodGuard policies;
  common-identity inventory and inventory-owner tests. PASS: **68 tests,
  500 assertions, no failures/errors/skips**.
- Test/expectation corrections included the lookup keyword, invalid Actor context
  enum, DISTINCT ordering and the recorder's actual validation exception type.
  These are not represented as product Red.
- `bundle exec rubocop app/operations/client_secret_revocation_committer.rb
  app/queries/authentication_credential_inventory.rb
  test/operations/client_secret_revocation_committer_test.rb
  test/policies/auth_method_guard_test.rb`: **FAIL**, one
  Rails/SkipsModelValidations finding on the conditional update_all transition.
  The other three files have no offenses. Formatting was corrected; no new
  suppression, exclusion or threshold change was added.
- `git diff --check`: PASS before adding this record.

## Unfinished activation requirements

The lint finding is unresolved and retirement is not connected to HTTP. No
Chronicle sender or physical recovery is proved here. The existing generic
RetentionPurgeJob still directly deletes app Secret rows; it must be replaced
with the single audit-aware path before activation. Source persistence is not
delivery. No production retention setting, schema, key, deployment, external
write or shared-database change was made. Tests prepare persisted Step-Up facts;
they do not substitute for a full authentication ceremony or real-browser test.
