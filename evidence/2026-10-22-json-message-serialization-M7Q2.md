# JSON-only authenticated message verification

- Revision: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`.
- The worktree contained unrelated existing changes and the uncommitted serialization changes
  described here. Results apply to that worktree, not the clean revision.
- Application message serialization now uses `JSON`, and the four previously implicit encryptor
  constructors explicitly use `serializer: JSON`. No Marshal rotation or compatibility reader was
  introduced. Previously issued Marshal messages are intentionally rejected, including encrypted
  queued delivery payloads; these require fresh issuance in JSON. No deployment, queue rewrite,
  production persistence operation, or recovery operation was performed.
- A standalone `RAILS_ENV=test bundle exec ruby /tmp/check-message-serialization.rb` booted the
  application and exercised public APIs without test-schema preparation or database writes.
  Eighteen checks passed: JSON resend and three delivery-purpose round trips; authenticated Marshal
  rejection for resend and those delivery purposes; JSON sign-in binding and Marshal rejection;
  sign-up and org binding refusal; three session-limit reference lookups; singular and plural
  signed-session reference refusal; and logout request refusal. The temporary probe used ordinary
  scalar/hash payloads and matching signing/encryption keys, never executable deserialization gadgets.
- `bin/rails test test/services/message_serialization_test.rb test/services/outbound_sensitive_payload_test.rb`
  did not reach test execution. Automatic `db:test:prepare` failed with `PG::DuplicateTable`:
  relation `publishing_media_files` already exists, in `CreatePublishingSchema` through
  `PublishingSchema.create_media_files`. No database repair was attempted and no schema dump changed.
  The six new regression tests remain unverified through the standard Minitest runner.
- RuboCop passed for the eleven affected Ruby files. The new test file was formatted and checked
  again after adding the remaining refusal cases. `git diff --check` passed.
- Framework source inspection and an initial runtime probe showed that `MessageVerifier#verified`
  propagates JSON parser errors for authenticated non-JSON bodies. Application verification entry
  points now classify `JSON::ParserError` as an invalid token, preserving their nil/empty refusal
  contracts. `MessageEncryptor` already converts serialization errors to `InvalidMessage`.
