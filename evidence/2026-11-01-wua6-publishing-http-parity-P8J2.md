# WU-A6 ORG Publishing write context parity

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. At the final status check the worktree had 538
changed tracked paths, 260 untracked paths, and no staged changes; no commit was created. The new
integration test and this evidence file are untracked additions. `four.md` is ignored by
`.gitignore` and was updated as a workspace note.

The first test invocation stopped during Rails boot because the host shell lacked the repository's
local JWT issuer environment. Sourcing `.env.container.devcontainer` for the test process allowed it
to boot; no environment file or configuration was edited.

`bin/rails test test/integration/wua6_publishing_context_parity_test.rb` passed: 1 run, 8
assertions, no failures, errors, or skips. The test sent real HTTP requests to the Base ORG
Publishing create endpoint with a valid Edit client assertion and signed operator access tokens
bound to separately seeded Normal and Standby OP roots. Both requests returned 201, persisted the
requested canonical slug, and attributed the new revision to the same active Operator. The exact
`wua6-%` EntrySlug residue count after the test was 0.

This verifies the downstream API authorization path with a directly seeded Standby root. It does not
verify Auth Standby ceremony to Visa Root issuance, the remaining AC-41 operation matrix, or WU-A6
closure. No application schema, migration, or production/Neon data was changed.

Scoped `bundle exec rubocop test/integration/wua6_publishing_context_parity_test.rb`,
`ruby -c test/integration/wua6_publishing_context_parity_test.rb`, and `git diff --check` passed.
The full suite was not run.
