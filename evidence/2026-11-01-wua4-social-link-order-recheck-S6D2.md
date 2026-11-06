# XDB-12 APP social-link order recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the
  worktree had 537 changed or untracked paths. It was already dirty; no commit was created.
- Inspected `Auth::App::Social::LinkCompletionsController#create`. The Client owner lock remains
  held while the OP device/token lock block consumes Step-Up evidence, the social candidate, and the
  grant. After that OP block returns, the controller calls `ExternalAuthenticationLinkUseCase`,
  which writes the identity and source audit in the Client principal transaction. The earlier
  `four.md` statement that the source link call occurs before the OP transaction ends is stale for
  this source ordering.
- Ran with `.env.container.devcontainer` loaded and `PARALLEL_WORKERS=1`:
  `bin/rails test test/integration/social_auth_link_test.rb test/integration/acme_social_link_completion_test.rb`
- Result: 19 runs, 136 assertions, 0 failures, 0 errors, 0 skips. This includes successful link,
  already-owned identity conflict, and refusal to replay the consumed candidate.
- Scoped `git diff --check` passed. No application or test files were edited for this recheck.

Independent-connection observation of the OP commit, injected source-write failure after that
commit, and crash-window recovery were not performed. XDB-12 remains partially verified, not closed.
Production, Neon, and external services were not accessed.
