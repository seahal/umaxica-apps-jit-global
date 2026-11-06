# WU-A11 CommonRedirect same-origin source recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the
  worktree had 503 modified tracked paths and 239 untracked paths; none were staged.
- Current `CommonRedirect#redirect_to_surface_url` calls `request_origin_url?`, which delegates to
  `RedirectOriginValue.same_origin?` with `request.base_url`. The value implementation compares
  scheme, normalized hostname and effective port.
- Ran
  `PARALLEL_WORKERS=1 RUBYOPT=-W0 bin/rails test test/values/redirect_origin_value_test.rb test/services/jump_rt/return_policy_test.rb`
  after loading `.env.container.devcontainer`: 24 runs, 544 assertions, 0 failures, 0 errors, 0
  skips. The origin-value cases include matching default/explicit ports and mismatching scheme, host
  and ports.
- The former `four.md` claim that `redirect_to_surface_url` compares only host is stale for the
  current checkout; no application or schema change was made. The separate Jump edge-catalog and
  external receiver-contract inventory remains open. No full suite or browser test was run.
