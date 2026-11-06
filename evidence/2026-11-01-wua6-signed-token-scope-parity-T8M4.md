# WU-A6 signed access-token scope parity

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 558 staged, unstaged or
  untracked status entries at verification; no commit was created. The test file was modified in
  that worktree.
- `test/services/security_jwt_auth_access_token_codec_coverage_test.rb` now encodes Normal and
  Standby operator access tokens from the same actor and token inputs, using a test-only ephemeral
  ES384 key. It decodes both through `SecurityJwtAuthAccessTokenCodec` and asserts identical
  `authenticated domain:operator read:org write:org` scopes while preserving the distinct
  `authn_ctx` claims.

## Verification

- Before change, the focused codec file passed: 7 runs, 20 assertions, 0 failures, 0 errors, 0
  skips.
- After change, the focused codec file passed: 8 runs, 28 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop test/services/security_jwt_auth_access_token_codec_coverage_test.rb` — 1 file
  inspected, no offenses.
- `ruby -c test/services/security_jwt_auth_access_token_codec_coverage_test.rb` — Syntax OK.
- `git diff --check -- test/services/security_jwt_auth_access_token_codec_coverage_test.rb` —
  passed.

This verifies signed-token scope parity through the codec boundary. It does not establish a Standby
Root issuance journey or the AC-41 per-operation Normal/Standby authorization matrix.
