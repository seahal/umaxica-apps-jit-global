# Identity ceremony candidate reference issuer evidence

Date: 2026-10-12

Repository state under test:

- Branch: `feature`
- HEAD: `e76194d7499d561f65c0762cdbd9d319898023b2`
- The worktree was already dirty. Existing application, test, migration and documentation changes
  were preserved; this evidence does not describe them as part of this slice.
- Tests used the run-owned PostgreSQL manifest `tmp/acceptance-isolated-20261010p8b-primary.json`
  with PostgreSQL 17.7 at `10.89.2.3:5432`. No shared or production database was used.

Scope:

- New TOTP, secret-credential and concrete APP/COM/ORG passkey candidate references use the shared
  `PublicId.generate` NanoID-21 issuer.
- The shared persistence boundary retries only a named unique `ref` index, with the finite
  `PublicId::MAX_COLLISION_RETRIES` budget; non-`ref` failures are not regenerated.
- Social candidate references were explicitly retained as UUID-v4 capability references because the
  browser link-completion controller accepts `AuthAdmissionBinding::REFERENCE_PATTERN`.

Commands and results:

1. Focused candidate/refusal collection:

   ```text
   bundle exec rails test test/services/identity/social_ceremony_contract_test.rb \
     test/services/identity/totp_ceremony_contract_test.rb \
     test/services/identity/secret_credential_ceremony_contract_test.rb \
     test/operations/identity_passkey_registration_committers_test.rb \
     test/operations/identity_totp_enrollment_issuer_test.rb \
     test/services/ceremony_candidate_write_refusals_test.rb
   ```

   Result: `51 runs, 533 assertions, 0 failures, 0 errors, 0 skips`.

2. Affected SocialAuth integration collection:

   ```text
   bundle exec rails test test/integration/social_auth_link_test.rb \
     test/integration/social_auth_app_flow_contract_test.rb \
     test/integration/acme_social_link_completion_test.rb
   ```

   Result: `40 runs, 328 assertions, 0 failures, 0 errors, 0 skips`.

3. Rails Gate 2, four workers:

   ```text
   bundle exec rails test
   ```

   Result: `15147 runs, 128249 assertions, 0 failures, 0 errors, 0 skips`.

4. Vitest Gate 2:

   ```text
   bun run test
   ```

   Result: `99 files passed, 1140 tests passed`.

5. Static checks:

   ```text
   bundle exec rubocop app/models/concerns/identity_ceremony_candidate_record.rb \
     app/services/identity_social_ceremony_candidate_store.rb \
     app/services/identity_totp_ceremony_candidate_store.rb \
     app/services/identity_secret_credential_ceremony_candidate_store.rb \
     app/operations/identity_passkey_registration_verification_committer.rb \
     app/operations/identity_totp_enrollment_issuer.rb \
     test/services/identity/social_ceremony_contract_test.rb \
     test/services/identity/totp_ceremony_contract_test.rb \
     test/services/identity/secret_credential_ceremony_contract_test.rb \
     test/operations/identity_passkey_registration_committers_test.rb \
     test/operations/identity_totp_enrollment_issuer_test.rb
   git diff --check
   ```

   Result: no RuboCop offenses; no whitespace errors.

The first full Gate 2 attempt exposed seven SocialAuth failures after an attempted NanoID change to
the social candidate reference and two stale refusal-test stubs. The SocialAuth failures were caused
by the existing UUID-only browser capability contract and were resolved by reverting that candidate
issuer to UUID. The refusal tests were updated to exercise the shared persistence boundary rather
than a removed `create!` call. The final focused collections and full gates above were rerun after
those corrections.

Not performed: CI, Podman/devcontainer recreation, production or external-service verification,
independent acceptance investigation, destructive database operations and remote synchronization.
