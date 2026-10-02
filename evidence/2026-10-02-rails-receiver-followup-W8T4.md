# Rails receiver follow-up: return TTL and ordered URL binding

- Date: 2026-10-02
- Commit: `845f84b281663786c4d4e0f6473fcf3ab2040b74` (feature). The worktree had uncommitted changes:
  this follow-up plus unrelated pre-existing work (sign entry rename, OIDC logout changes, docs).
- Scope: `docs/operations/rails-receiver-followup.md` items 1 and 2 from the Jump repository.
- Previously reported pre-deployment acceptance was taken as a premise and not repeated. No
  production probe, secret change, or deploy was performed.

## Changes verified

1. Return-token lifetime is independent of issuance. `JumpRtReturnVerifier::MAX_RETURN_TTL` is a
   fixed 30 s (`SecurityTokenLifetimes::JUMP_RT_TTL`); `JUMP_RT_TTL_SECONDS` (1..30) now only
   affects Rails issuance. Time claims must be JSON integers. The jwt gem applies `leeway` to
   exp/nbf only, so `SecurityJwtJumpRtTokenCodec.decode_with_key` now passes
   `verify_iat: { leeway: }`. Before this change, an iat even 1 s ahead was rejected, despite
   `LEEWAY = 5`.
2. URL binding uses ordered decoded pairs (`JumpRtReturnUrlValue`, WHATWG form-urlencoded
   parse/serialize). Rejected: rt count other than one on the request, any rt on the signed url,
   `rt[` keys (including percent-encoded), duplicated
   redirect_uri/state/nonce/code/next/return_to, a request rt value different from the verified
   token, and reordered pairs. The concern triggers on the raw query (not `params[:rt]`), and it
   redirects to the verified serialization instead of rebuilding a Rack Hash.

## TDD observations (Red before Green)

- Issuance TTL 1/10/29 with a 30 s return token: failed `invalid_claim` before the fix.
- String exp, string/null nbf, and 30.5 s lifetime: accepted before the fix.
- iat 5 s ahead: rejected before the fix (library iat leeway was 0).
- Reordered query, a second rt, duplicate `next`, a mismatched rt value, and rt in the signed url:
  accepted before the fix.
- Controller redirect with repeated `tag` pairs: the target lost a pair before the fix.

## Commands and results

`PUBLIC_JUMP_GATEWAY_URL=https://jump.umaxica.net` was set per command. The container
environment had a scheme-less value that fails boot validation; no env file was changed.

- `bin/rails test test/values/jump_rt_return_url_value_test.rb test/services/jump_rt test/integration/jump_rt_return_verification_test.rb test/tooling/architecture_baseline_test.rb test/controllers/palm`
  → 226 runs, 0 failures, 0 errors.
- `bin/rails test` → 12493 runs, 84922 assertions, 0 failures, 0 errors, 2 skips (pre-existing).
- `bun run test` → completed (no JavaScript changes).
- `bin/rubocop` on all touched files → no offenses.

Controller coverage: `test/integration/jump_rt_return_verification_test.rb` drives the real
`JumpRtReturnVerifier` with Jump-signed ES384 test tokens on `auth.umaxica.com` (Auth com). It
covers success with order, repeated-pair, and `%2B` preservation, plus rejection of reordered
pairs, a second rt, a nested rt key, a duplicated reserved parameter, and a nested-only rt key.

## Jump shared receiver contract

- Fixture: `test/fixtures/files/jump_receiver_contract.json` (Jump `service_version` 0.3.0,
  schema 1). The user supplied its contents by paste, not as a file, so this repository's copy was
  re-serialized. SHA256 of the stored copy:
  `7f884dcc348ff61cd94643b4dfbc0c5e27caa21fbf570abed81084b59471339e`. It is not verified
  byte-identical to the Jump repository file, and the Jump commit is unknown.
- `test/services/jump_rt/receiver_contract_test.rb` runs all 13 `url_cases` through the real
  `JumpRtReturnVerifier`. In each case, the literal rt value `returned` is replaced by an
  ES384 token signed with `url` = `signed_url`. It also checks that the contract's
  inbound_max_ttl (30), clock tolerance (5), max token characters (8192), schema, rpl, sub,
  alg, and typ match the receiver constants.
- Result: 15 runs, 0 failures.
- Discrimination check: with the HEAD (pre-change) verifier temporarily restored, 5 cases failed
  (ordering is binding, duplicate rt, array rt, nested rt, missing exact rt). The current file
  was restored afterwards.
- Full suite after adding it: `bin/rails test` → 12508 runs, 84954 assertions, 0 failures,
  0 errors, 2 skips.

## Issuance-side query normalization

- `JumpRtIssuer#strip_dangerous_query` now uses `UrlSearchParamsValue`, a shared ordered-pair
  WHATWG parse/serialize value that `JumpRtReturnUrlValue` also uses. Rack Hash normalization was
  removed. Blocked keys are matched after percent-decoding in bare and bracketed forms.
  Remaining pairs keep their order and repeats.
- Red before Green: `?tag=b&rt=stale&tag=a&q=a%2Bb&s=a+b` was signed with a repeated pair lost.
  Bracketed, encoded-key, and preserved-position cases already passed before the change.
- Contract change: `?a=scalar&a[b]=nested` was refused before only because Rack raised on
  conflicting shapes. It is now signed as two ordinary pairs, and the test was rewritten to
  record this.
- Not changed: `RedirectsExternalTargetResolver` and `RedirectsPathTargetResolver` still use
  Hash-based query handling. They are separate redirect paths outside this follow-up.
- `bin/rails test` → 12521 runs, 84976 assertions, 0 failures, 0 errors, 2 skips.

## Not completed

- GitHub check enforcement, production configuration, and rollback verification remain separate
  gates. These tests do not close them.
