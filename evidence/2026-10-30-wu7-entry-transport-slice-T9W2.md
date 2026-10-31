# WU-7 slice 7: com entry transport resolves the issued JWT — matched read-back closes

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; nothing committed; worktree = WU-3..WU-7-slice-6
  plus this slice.

## Root cause found and fixed

The matched read-back leg failed because `PreferenceBase#anonymous_com_claim_shape?` checked
`preference.class.name` — it was being called with the *preference class itself*, so
`preference.class` evaluated to `Class` and the check always returned false. Every com surface
therefore kept the legacy access-cookie name list, and the matched GET resolved no credential,
falling through to an unpersisted default row. Fixed by normalizing the argument: a `Class` is used
as-is, an instance reads `preference.class`. One-line fix; the com surface now resolves
`access_token_cookie_names` to `["preference"]` (the section 4.1 name), matching what the write
issues.

With that fix the entry transport's GET branch (`ensure_preferences_record` →
`load_access_token_preference_record!` → `matching_access_token_value` → com-shape decode →
`find_by(public_id:)`) binds the browser to the written row, and
`readable_cookie_state`'s constant-time binding check reports the stored consent.

## Verification

- Integration journey (two tests): the four-cookie consent write AND the matched read-back
  (`cookies[preference] = issued JWT; cookies[preference_binding] = raw; GET cookie screen` renders
  `consented: true`) — 2 runs, 28 assertions, 0 failures, 0 errors.
- Full WU-7 slice set (journey + boundary + binding write/read + payload + token shape + legacy
  claims): 22 runs, 133 assertions, 0 failures, 0 errors.
- Directory regression: `test/controllers/base/com test/controllers/concerns/
  test/integration/preference_web_csrf_test.rb` — 757 runs, 9,087 assertions, 2 failures, both
  recorded baseline ids (`AuthenticationSessionRevokerTest` line 874,
  `SignOrgVerificationBaseDirectCoverageTest` line 950).
- Rubocop clean on the four touched files after `-A`; `ruby -c` passes; all temporary probes
  removed from app code.

## Remaining in WU-7

- The refresh/DBSC machinery still rides the com *entry/create* path (`persist_new_preference_record!`
  keeps issuing a refresh cookie on first creation); removing it from the com branch is the next
  slice and does not affect the issuance contract above.
- Section 4.3 destructive columns — owner shape-review gate (unchanged).
