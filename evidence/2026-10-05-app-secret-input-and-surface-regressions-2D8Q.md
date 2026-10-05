# Input boundaries and current surface regressions

Observed 2026-10-05 UTC, through 15:29:14+00:00, against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f` with uncommitted changes.
Ruby commands used the guarded disposable `codex_integrity_20261005recovery_*`
fleet on PostgreSQL 17.7. No shared DDL application or full suite/E2E run occurred.

The lookup eligibility example had constructed a claimed row with only a time
and arbitrary operation UUID. The current database correctly rejected the
missing flow/browser binding. The test now uses an active owner, a server-issued
local admission, an admitted ceremony and `ClientSecretClaimCommitter.call!`.
The database constraint and production authorization remain unchanged.

Added twelve admitted Secret HTTP rejection cases for missing/null/empty,
JSON numeric zero/array/object, 31/33 characters, invalid Base58, embedded NUL,
exact case mismatch and unknown 32-character input. Each uses a legitimate Base
admission redeemed through Auth, enabled CSRF and a valid third-party Turnstile
stub. Online limits remain active; independent cases use distinct request
addresses. Rejection preserves credential state facts, token/outbox counts and
the flow's empty actor/token binding.

Added native form constraint cases for 31/32/33 characters, valid uppercase and
digit values, excluded 0/O/I/l and NUL. DOM validity checks preserve the submitted
text. Well-formed unknown values remain valid syntax and are checked by the
server. Initial uncontrolled input is empty and has no value attribute; these
tests do not introduce a JavaScript Secret state or storage object.

Commands and results:

- Guarded runner `test test/queries/client_secret_lookup_query_test.rb
  test/models/client_secret_credential_test.rb test/controllers/auth/route_naming_test.rb
  test/integration/routes/auth_sign_ceremony_route_contract_test.rb
  test/services/recovery_passcode_top_up_test.rb
  test/unit/security/org_emergency_access_invariants_test.rb`:
  initial seed 1175, 44 runs, 964 assertions, 1 error from the invalid claimed
  fixture. After the public-claim correction, seed 13845:
  **44 runs, 968 assertions, no failures/errors/skips**, 1.453316 seconds.
  This includes app-only route presence, com/org absence, existing recovery
  distribution and org Emergency invariants in the named test files.
- Guarded runner `test test/controllers/auth/app/in/secrets_controller_test.rb`:
  initial seed 39004, 13 runs, 69 assertions, 12 errors from incorrectly using
  a nonexistent admission `.flow` accessor. Corrected to its public `.transaction`
  field. Seed 22831: **13 runs, 93 assertions, no failures/errors/skips**,
  4.017535 seconds. The legacy GET and unadmitted rejection case also passes.
- `bun run test spec/pages/auth/app/secret_sign_in_presentation.test.tsx
  spec/features/auth/signup/secret_distribution_notice.test.tsx`:
  final **2 files, 19 tests passed**, 776 ms, start 15:29:13 UTC.
- `bundle exec rubocop` on the changed query and HTTP tests: 2 files, no
  offenses after formatting correction. Direct `node_modules/.bin/oxlint` and
  `node_modules/.bin/oxfmt --check` for the frontend test exited 0.
  An earlier `bunx oxlint` command was unavailable (exit 127); this was not
  counted as a successful static check. `git diff --check` exited 0.

These are the named boundary and surface checks, not a full authentication
regression or real-browser history/cache proof. TTL values remain accepted;
the separate issuance-authority storage shape still awaits explicit approval.
Live-owner replay-barrier retirement and current DDL reconstruction remain open.
