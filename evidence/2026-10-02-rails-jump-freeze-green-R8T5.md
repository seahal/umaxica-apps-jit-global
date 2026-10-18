# Rails Jump freeze verification (green)

Date: 2026-10-02. Verified commit: `fcb72366594cbab5f94940e79efb9c916a6f0d6c`. This follows
`2026-10-02-rails-jump-final-freeze-Q7M3.md` (left unchanged), whose two open errors are fixed here:

- `7ad8da2` adds a per-test ENV snapshot/restore in `test/test_helper.rb`; the copied
  `load_jump_rt_env!` helpers had leaked `JWT_<NAMESPACE>_*` into later tests.
- `fcb7236` keeps `Rack::Test::CookieJar#merge` in `oidc_rp_browser_flow_test.rb`; the `Lint/Void`
  autocorrect in the pre-commit hook had rewritten it to the nonexistent `merge!`.

## Environment

The checks ran in a fresh `git worktree` of the exact commit. `git status --short` was empty and
`git diff --check` exited 0. Ignored inputs were provided the same way as in Q7M3: `vendor/bundle`,
`node_modules`, `.env`, `.env.local`, `config/credentials/*.key`, `tmp/local_jwt_keysets.json` and
built assets. Every run set `PUBLIC_JUMP_GATEWAY_URL=https://jump.umaxica.net`.

## Results

- Focused Jump command (as in Q7M3): **359 runs, 1,995 assertions, 0 failures, 0 errors, 0 skips**,
  seed 18821.
- `bin/rails test`: **12,397 runs, 84,735 assertions, 0 failures, 0 errors, 2 skips**, seed 4565,
  144.5 s. The two skips are pre-existing.
- `bin/rails test --seed 39593` (the seed that exposed the ENV leak): **12,397 runs, 0 failures, 0
  errors, 2 skips**.
- `erb_lint --lint-all`: no errors.
- rubocop, by the pre-commit hook on each changed Ruby file: no offenses.

Repository-wide rubocop (63 offenses) and `format:check` (3 TSX files) are unchanged from Q7M3. They
are outside the files touched by this work.
