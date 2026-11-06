# WU-A4 XDB-07 Email removal HTTP test transaction mismatch

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree was already extensively dirty and had no staged changes. No change to the Email
controller test file remains.

The targeted combined command
`UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 bin/rails test test/operations/identity_email_preference_committer_test.rb test/controllers/base/app/identity/emails_controller_test.rb`
ran 13 tests / 69 assertions and failed once:
`Base::App::Identity::EmailsControllerTest#test_destroy_with_fresh_step_up_removes_the_email`
expected HTTP 303 but received 503. The controller test uses default transactional tests.
`IdentityCredentialRemovalCommitter` checks for an independent OP commit and returns a transaction
conflict when called from that fixture transaction. This result does not verify the production HTTP
success path.

A local nontransactional test-harness experiment was reverted. Its synthetic
`BaseSelectorBootstrapAuthority` call created owner rows protected against independent destruction;
the standard cleanup helper could not remove the actor. Read-only inspection of the local test DB
found synthetic Client id `980190963`, with no Email, Passkey, token or device rows, and one each of
`ClientPersonaOwnership`, `EnterpriseOwnership` and `ClientAuthorityLock`. These owner rows were not
directly deleted. The original test file was restored; no code or test change from this experiment
remains.

HTTP success under an independent OP commit and safe fixture cleanup remain unverified. No
production or development database was changed.
