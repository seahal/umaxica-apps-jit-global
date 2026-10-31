# Passkey rename foreign-device probe

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A temporary focused APP test attempted to attach one Client's token to another Client's device before invoking Passkey rename. The update failed with `ActiveRecord::InvalidForeignKey` for `fk_client_tokens_on_user_id_and_device_session_id`; the test ended with 1 error and 0 assertions because it did not reach the operation. Its temporary code was removed.
- The checked-in APP and ORG migration files both define and validate composite owner/device foreign keys. This local probe established enforcement only for the APP test database; the ORG constraint and deployed databases were not independently exercised.
- The result does not establish all Passkey ownership or concurrency boundaries and no production change was made from this probe.
