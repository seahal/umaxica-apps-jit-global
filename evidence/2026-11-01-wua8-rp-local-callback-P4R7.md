# WU-A8 RP-local OIDC callback slice

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree was already extensively modified; this slice remains uncommitted. No commit,
  migration, production/Neon operation, or external OIDC request was made.
- `OidcCallback` now verifies the ID Token against the OP JWKS and commits the verified issuer,
  realm, client and subject to the RP's own cell. It no longer looks up the OP/Zenith account or
  calls UserInfo to create/select the RP principal. The obsolete `OidcRpIdentityProvisioning`
  concern was deleted. A source search found no references to that concern or its
  provisioning/UserInfo callback methods under `app/controllers` and `app/services`.
- Tech retains its independent `tech.access` check through `TechCapabilityClient` before local RP
  credentials are issued. A denial requests revocation of only the exchanged refresh token and does
  not issue RP cookies or rows. The Tech tests stub both network boundaries.
- The session-limit integration now observes the read-only Visa result GET form and submits its
  signed same-origin POST continuation. Its callback assertion resolves the returned actor to the
  local Core RP principal and its verified identity binding.
- The Tech/Palm participation ADR now records the WU-A8 callback identity amendment. The ownership
  manifest's stale `OidcCallback` direct-read entry was removed; only that entry was rechecked, and
  model counts and other reader rows were not regenerated.

## Verification

- The shared, Palm, Base APP/ORG and Tech callback test group passed: 40 runs, 349 assertions, 0
  failures, 0 errors, 0 skips.
- `test/integration/base_rp_browser_flow_test.rb`, `test/integration/core_rp_browser_flow_test.rb`,
  and `test/integration/oidc_rp_browser_flow_test.rb` passed together: 18 runs, 262 assertions, 0
  failures, 0 errors, 0 skips. This includes the APP session-limit journey through the result GET
  form and POST continuation.
- Scoped RuboCop passed for the six changed callback/test files. `git diff --check` passed.
- An initial test command without the repository devcontainer environment failed during Rails boot
  because the local `preference_com` JWT issuer was absent. The tests above were run after loading
  `.env.container.devcontainer`; no test case ran in the failed invocation.

## Not verified

- This is one WU-A8 slice, not WU-A8 or `two.md` closure. RuntimeRole removal, all-RP local
  authentication, logout/RFC7009 sequencing, Base identity-operation ownership and full-suite
  comparison remain open. No full suite was run in this slice.
