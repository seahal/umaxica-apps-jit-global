# WU-7 slice 5: section 4.7 read half — consent renders only through the binding match

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; nothing committed; worktree = WU-3..WU-7-slice-4
  plus this slice.
- Scope: the read half of section 4.7 on the com anonymous surface — the *page* and *JSON* consent
  reads are gated by the binding cookie, and never mint/extend/delete.

## Code

- `app/controllers/concerns/preference_browser_binding.rb` — new `readable_cookie_state` (private
  concern method, reachable only through the public read surfaces):
  - stored per-category state is reported as-is while the consent is readable;
  - "readable" is: consent not granted, OR the row carries no binding digest (a pre-D-57 row), OR
    the presented binding cookie digests to the stored digest (constant-time compare via
    `PreferenceBrowserBinding.matches?`);
  - a missing/mismatched binding renders every consent-derived category declined, and changes
    neither the row nor the cookie.
- `app/controllers/concerns/preference_resource_sync.rb` — `resolved_preference_cookie` applies the
  same gate to the JSON read path (`preference_response_payload`): a stored consent with a binding
  digest that the presenting browser cannot match reports the default no-consent state.
- `app/controllers/concerns/base_preference_screen_page.rb` — the com cookie screen renders its
  `categories` values through `readable_cookie_state` instead of the raw row readers.

## Verification

- New `test/controllers/concerns/preference_browser_binding_read_test.rb` (public page boundary):
  - a granted consent row *without* a binding digest stays declined on the rendered page (the
    browser presented nothing) and the row keeps `consented=true` with no digest — the gate never
    writes on read;
  - a *missing* cookie and a *mismatched* cookie against a bound consent row render declined while
    the row stays `consented=true` with its digest intact.
  Result: 2 runs, 12 assertions, 0 failures, 0 errors.
  (The *matched* case needs the browser bound to the fixture row through a com JWT — that is the
  §4.4 write-boundary integration journey, next slice; the matched branch itself is the constant
  -time compare already covered by `PreferenceBrowserBinding.matches?` in the slice-4 tests.)
- Slice-4 + read tests together: 6 runs, 30 assertions, 0 failures, 0 errors.
- `test/controllers/concerns/ + test/controllers/base/com` directory run: 734 runs, 8,966
  assertions, 2 failures — both are recorded baseline ids
  (`AuthenticationSessionRevokerTest#test_revoke_all_for_revokes_each_token_from_the_relation` is
  baseline line 874; `SignOrgVerificationBaseDirectCoverageTest` likewise).
- Rubocop: the four touched files end clean (visibility declarations per Umaxica rule); `ruby -c`
  passes.

## Not in this slice

- Web Push option/child tables (section 4.3 columns) and the Visa sign-out copy of the binding
  record (WU-9); the §4.4 JWT-bound write journey (which also gives the matched-read integration
  case); the §4.3 destructive column migration (owner shape-review gate).
