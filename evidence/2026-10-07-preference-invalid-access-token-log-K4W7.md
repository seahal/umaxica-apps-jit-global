# Preference "invalid or missing access token" log line diagnosis

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`.
- The worktree had uncommitted changes, but none in the five files cited below
  (`git status --short` on them printed nothing).
- Scope: read-only diagnosis of `log/development.log` (10090 lines) and the current code. No file
  was changed, no test was run, and the behavior was not reproduced in a browser.

## Question

The development log contains `Preference のアクセストークンが不正、または未設定です。`. The
expectation was that a failing preference credential is discarded and reissued automatically.

## Findings

The line has one emitter. `grep -rn invalid_access_token app lib config/initializers` finds the
translation key `errors.preference.cookie.invalid_access_token` used only at
`app/controllers/concerns/preference_web_cookie_endpoint.rb:93`, in
`decode_and_verify_preference_jwt`, at `info` level. It is logged whenever
`decode_matching_access_token` returns no payload. `decoded_preference_payload` passes the result of
`matching_access_token_value` straight in, so an absent access cookie and an undecodable one produce
the same line. The log cannot tell the two apart.

The line appears 4 times (lines 9725, 9743, 9793, 9804), every time inside
`Base::App::Api::V0::Preferences::CookiesController#show`, and every one of those requests completed
`200 OK`. That action renders `{ show_banner: show_banner? }`, and `cookie_consent_state` falls back
to all-false consent without a payload, so the response is the ordinary anonymous one.

The browser held a refresh credential for a preference row that no longer existed. Line 9810 logs
`preference.token.refresh.failed` with `reason: invalid_or_inactive_refresh_token`, and line 9811
logs `preference.credential.recovery` with `failure: record_not_found`,
`category: credential_rejection`, `stage: read_only_lookup`, `outcome: detached`, both for
`GET /preference/cookie/edit`. Why the row was missing is not recorded in the log.

The state recovered on the next write. Lines 9832 and 9845 are
`Base::App::Preference::CookiesController#update`. The 8 later
`Api::V0::Preferences::CookiesController#show` requests (lines 9875 to 9965) do not log the line.

## Why no reissue happened on the read

- `PreferenceTransport#set_preferences_cookie` (`app/controllers/concerns/preference_transport.rb:31`)
  returns early for GET and HEAD after reading the access credential, doing a read-only refresh
  lookup, and deleting confirmed-unusable cookies. Creation, rotation, and issuance run only on the
  non-GET branch.
- `PreferenceBase#ensure_preferences_record` (`app/controllers/concerns/preference_base.rb:289`)
  returns an unpersisted `preference_class.new` on GET and HEAD.
- `adr/invalid-browser-credential-recovery.md` (Accepted 2026-09-26) states this as the "GET refresh
  prohibition": detaching or deleting an invalid cookie on GET is allowed, consuming a refresh
  credential to issue a new access credential on GET is not.
- `Base::App::Api::V0::Preferences::CookiesController` declares
  `skip_before_action :set_preferences_cookie`, so the banner endpoint does not run even the
  detach-and-delete step. The stale cookies stayed until the HTML `edit` request at line 9808.

`git log -S'must not create its server-side record'` dates the GET no-create rule in
`preference_base.rb` to commit `47312b920` (2026-09-25).

## Conclusion

The line reports an ordinary state, a browser without a usable preference access credential calling
the banner endpoint, not a failure. Automatic discard still happens on HTML reads; automatic reissue
on reads was removed on purpose and now happens on the next preference write. The wording and the
missing absent/undecodable distinction make the line read like a fault. Follow-up is recorded in
`plans/backlog/preference-access-token-log-noise.md`.
