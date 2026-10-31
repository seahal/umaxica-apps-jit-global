# WU-7 slice 2: anonymous com JWT claims reshape per section 4.2 (D-54)

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; worktree carries WU-3..WU-7-slice-1 plus this
  slice; nothing committed.
- Scope: the com token's *claims contract*. Per section 12.7 "the shared branch the app/org surfaces
  use stays until WU-9, and no dual running of old and new tokens within one realm" — the codec now
  branches on the writing model class: `ComPreference` issues the section-4.2 claims; `AppPreference`
  / `OrgPreference` still issue the pre-WU-7 claims and decode on the legacy branch.

## Codec contract after this slice

- `SecurityJwtPreferenceTokenCodec.encode` for `preference_type == "ComPreference"` emits exactly:
  `iss` (the shared fixed preference issuer), `sub` (anonymous row's `public_id` string), `aud` =
  the fixed realm token `"com"`, `iat`, `exp` (`ACCESS_TOKEN_TTL` seconds, existing 400-day), `jti`,
  and `preferences` (closed-key object; keys fixed at
  `theme language timezone currency date_format time_format motion density page_size`). It no longer
  emits `client_id`, `host`, `preference_type`, `public_id`, `nbf`, or `scope`, and the same closed
  set is enforced at encode: unknown keys or non-string values raise `ArgumentError` inside the
  encode rescue and return `nil` (log entry `preference.token.encoding_failed`).
- `SecurityJwtPreferenceTokenCodec.decode` detects a com token by its unverified shape (has
  `preferences`, lacks `client_id` and `preference_type`) and runs a dedicated decode: signature on
  the active key, `iss` exactly, `aud` exactly `"com"`, all of
  `iss aud exp iat jti sub preferences` required, `exp` verified, then the same closed-key
  enforcement on the *decoded* `preferences`; any closed-set or type violation makes decode return
  `nil`. Anomaly reporting paths (EXPIRED / AUD_MISMATCH / claim errors / decode errors) preserve the
  existing operational vocabulary with a `com` host label in the report.
- The app/org branch is untouched: the existing claims test
  (`test/values/security_jwt_preference_token_codec_claims_test.rb`) still passes unchanged
  (3 runs / 24 assertions green).

## Verification

- New `test/values/anonymous_com_preference_token_shape_test.rb`:
  - a genuine com token decodes and its payload keeps every legacy claim out while `sub`/`aud`
    and the full closed `preferences` set come back through `decode`;
  - an unknown preferences key (`web_push`) encodes to `nil`;
  - a non-string value (`theme => 7`) encodes to `nil`;
  - a token whose `aud` was re-signed to `"app"` refuses to decode.
  Result: 4 runs / 22 assertions / 0 failures / 0 errors / 0 skips.
- Regression: legacy claims test + com surface slice in one run —
  7 runs / 47 assertions / 0 failures / 0 errors; and
  `bin/rails test test/controllers/base/com test/integration/preference_web_csrf_test.rb`
  test/controllers/base/preference_authority_slice_1f_test.rb → 38 runs / 342 assertions / 0
  failures / 0 errors.
- Rubocop `-A` on the codec and the new test file, ending "no offenses"; `ruby -c` passes.

## Not in this slice (next steps in the same WU-7 loop)

- Visa `sign_in`/`sign_out` read surfaces (WU-9) and the section 4.3 destructive column migration
  (owner shape-review gate, two.md section 3.0) remain open; this slice is claims-contract only.
