# WU-7 slice 3: com preference payload uses the section-4.2 closed key contract

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; nothing committed; worktree = WU-3..WU-7-slice-2
  plus this slice.
- Scope: the com write issuance path now *builds* the payload carrying the section 4.2 shape so the
  slice-2 codec branch actually receives the closed-key object instead of legacy claims. App/org
  payload construction is untouched (legacy contract stays until WU-9).

## Code

- `app/controllers/concerns/preference_base.rb` — `build_preferences_payload` branches on
  `preference.class.name == "ComPreference"`:
  - `build_anonymous_com_preferences_payload`: long-name closed-key payload whose values come from
    the existing per-realm optionography helpers (`option_id_to_language/theme/timezone` and
    `option_id_to_preference_value` for currency/date_format/time_format/motion/density/page_size);
    `compact_blank` keeps out unset keys. Region and consent keep out of the token (D-55/57).
  - `normalized_theme_key` converts the storage short codes (`li/dr/sy`) to the long contract
    values (`light/dark/system`).
  - app/org payloads continue through the ver/lx/ri/tz/ct path unchanged.

## Verification

- New `test/values/anonymous_com_preference_payload_build_test.rb`: a fresh anonymous com row with a
  `language => ja` and `theme => system` child records emits exactly `{"theme" => "system",
  "language" => "ja"}` — closed-key subset semantics, no consent/region/legacy keys. 1 run, 9
  assertions, 0 failures/errors.
- With slice-1 (write boundary) and slice-2 (token claims) in the same run:
  `PARALLEL_WORKERS=1 bin/rails test test/values/anonymous_com_preference_{payload_build,token_shape}_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb test/controllers/base/com test/integration/preference_web_csrf_test.rb`
  → 29 runs, 129 assertions, 0 failures, 0 errors.
- `bin/rails test test/controllers/base`: 856 runs, 5,476 assertions, 21 failures, 1 errors — every
  failing identifier inside the recorded WU-0 baseline plan (`AuthorityOwner…`, `Welcome…`, slice-1c
  and `BaseOauthFreshnessE3Test` are pre-existing baseline ids; the comparison script reports 0 NEW).
- Rubocop: the codec, the payload change and both test files end clean; `ruby -c` passes on all.

## Next steps in WU-7 (unchanged)

- D-57 four-cookie contract (`__Host-preference_binding` issuance at Base-consent save) and the
  section 4.3 destructive migration (owner gate, two.md section 3.0).
