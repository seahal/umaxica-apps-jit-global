# Passkey slot classification and writer serialization

Verified on 2026-10-04 against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes and unrelated shared-worktree changes. All Rails checks used the owned isolated manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`; preparation was limited to its APP ticket database. No shared database or schema reconstruction was performed in these checks.

APP/COM revoked and deleted history, and ORG revoked history, no longer consume the existing four registration slots. Validation reads current writer state rather than a loaded association. Creation repeats the bound check under the actor row lock. Tests cover three, four and attempted five slots, retained history, stale associations and two independent PostgreSQL writers competing for one remaining slot on each surface. One writer succeeds and one receives RecordInvalid; four active records remain.

The initial six regression cases failed before the fix (seed 19471: three failures and three errors). The first new race had an invalid semantic-base connection switch; it was corrected to the public connection-owning base. A combined run then exposed an old test deleting ACTIVE reference data despite existing FK references. That case now verifies the FK refusal and retained credential, using a nested rollback boundary. The ORG limit test now uses actual records instead of a count-only relation fake.

Commands used this environment prefix:

```sh
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261003auth6f3 POSTGRESQL_ISOLATED_TEST_MANIFEST=/home/global/workspace/tmp/auth-boundary-isolated-20261003auth6f3.json POSTGRESQL_TEST_PREPARE_DATABASES=codex_integrity_20261003auth6f3_app_ticket PARALLEL_WORKERS=1
```

- `bin/rails test test/models/client_passkey_test.rb test/models/visitor_passkey_test.rb test/models/operator_passkey_test.rb test/models/auth_ceremony_revocation_concurrency_test.rb`: seed 44030, 53 tests, 319 assertions, zero failures/errors/skips.
- `bin/rails test test/integration/root_login_establishment_flow_test.rb test/integration/org_root_login_establishment_test.rb test/integration/totp_registration_boundary_test.rb test/operations/base_bootstrap_admission_issuer_test.rb`: seed 48738, 18 tests, 425 assertions, zero failures/errors/skips. Provider responses and Turnstile remain stubbed in the ORG journey.
- RuboCop on the three models and four corresponding test files: seven files, no offenses after formatting corrections.

This is the registration-capacity prerequisite for durable removal history. Atomic last-method removal, admitted credential management and Base Passkey candidate commitment remain unfinished. Browser verification belongs to the user; OTP logging remediation remains excluded. These results do not establish full R01–R16 completion.
