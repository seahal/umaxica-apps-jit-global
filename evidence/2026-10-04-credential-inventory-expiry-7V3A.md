# Writer-time expiry in credential inventory

Verified on 2026-10-04 against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication work and unrelated shared-worktree changes. Rails commands used the owned isolated manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, APP ticket-only preparation and one worker. No shared database, migration or reconstruction was changed.

AuthenticationCredentialInventory previously counted verified/active APP/COM Passkey, Email and Telephone rows after discard_at. The first expiry regression failed at exact equality (seed 32326: two tests, one failure). The query now evaluates its existing inventory reads on the surface writer and obtains one writer-clock snapshot. Retained APP/COM rows count only when discard_at is strictly later. UV Passkey inventory uses the same condition. Existing app Secret availability uses that same decision instant; ORG records without discard_at retain their status-only rule. Nil actor keeps the empty inventory; unsupported actor types fail explicitly.

Boundary tests use real records and the public model database clock at one microsecond before, exactly at and one microsecond after expiry for all six APP/COM credential partitions. Expired recovery Email cannot mask the COM Passkey result. Removal tests prove that an expired Passkey or Email cannot authorize removal of the sole usable Passkey; the active target, original freshness and root session remain. Existing independent deletion/finalization races remain covered. No new credential lookup was installed on ordinary page/API access; these are the existing inventory query sites.

Environment prefix:

```sh
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261003auth6f3 POSTGRESQL_ISOLATED_TEST_MANIFEST=/home/global/workspace/tmp/auth-boundary-isolated-20261003auth6f3.json POSTGRESQL_TEST_PREPARE_DATABASES=codex_integrity_20261003auth6f3_app_ticket PARALLEL_WORKERS=1
```

- `bin/rails test test/services/authentication_credential_inventory_common_identity_test.rb test/operations/identity_credential_removal_committer_test.rb test/policies/auth_method_guard_test.rb test/services/auth_method_guard_coverage_test.rb test/models/auth_ceremony_revocation_concurrency_test.rb`: seed 64453, **41 tests/400 assertions**, zero failures/errors/skips.
- `bin/rails test test/integration/root_login_establishment_flow_test.rb test/integration/org_root_login_establishment_test.rb test/integration/totp_registration_boundary_test.rb test/controllers/base/app/identity/emails/registrations_controller_test.rb test/controllers/base/com/identity/emails/registrations_controller_test.rb test/operations/base_bootstrap_admission_issuer_test.rb`: seed 5625, **48 tests/577 assertions**, zero failures/errors/skips. Provider/Turnstile seams remain stubbed where the integrated cases document them.
- RuboCop on the query and two changed test files: three files, no offenses after formatting. Scoped whitespace check passed.

This fixes expiry classification in the shared consumer decision. Temporary credential cooldowns, admitted credential management, Base Passkey candidates and the complete original protected-operation inventory still require their own evidence. Browser verification remains user-owned; OTP logging remediation remains excluded. Full R01–R16 completion is not claimed.
