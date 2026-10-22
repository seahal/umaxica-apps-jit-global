# Session Cookie Host-Only Migration

Date: 2026-10-21. Commit: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`. The worktree had uncommitted
changes, most of them not part of this work; the change below is in `lib/jit_session_cookie_config.rb`
and the two test files named here.

## Change

At the owner's decision, the Rails session cookie no longer carries a `Domain` attribute in
development and test (previously the apex, for example `.umaxica.app`, through `CoreCookieDomain`),
and no longer carries `Partitioned` in production. `SameSite=Lax`, `HttpOnly`, production `Secure`
and the `__Host-session` name are unchanged.

Sources read: vendored Rails `182206b65670` (`actionpack/.../session/cookie_store.rb`,
`actionpack/.../cookies.rb` `:domain` documentation, `railties/.../finisher.rb:53`), rack-session
2.1.2 `Rack::Session::Abstract::Persisted::DEFAULT_OPTIONS` (`domain: nil`), Rails Guides security
and configuring pages, and RFC 6265bis draft-20 §4.1.2.3, §4.1.3.2 and §8.6.

## Observations

- `RAILS_ENV=test bin/rails runner 'p Rails.application.config.session_options'` printed
  `{expire_after: 14 days, key: "session", secure: false, httponly: true, same_site: :lax, cookie_only: true}`.
- Full `bin/rails test` after the change: 18420 runs, 61 failures, 2 errors. Compared with the run
  before the change (59 failures, 1 error), no earlier failure disappeared and exactly three were
  added, all asserting the removed attributes:
  `Jit::SessionCookieConfigTest#test_session_options_partition_production_cookies` and two cases in
  `Security::Invariants::CookieSecurityInvariantTest`. The remaining failures are the pre-existing
  session fixation containment groups and are unrelated to the cookie domain.
- The obsolete `partitioned` unit case was removed; the two invariant cases now assert that the
  session cookie has no `Domain` and no `Partitioned` attribute. Those two files: 21 runs,
  0 failures, 0 errors. RuboCop: no offenses on the three files.

Not verified: browser behavior in development (no browser session was run), and cookies other than
the Rails session, which still use `CoreCookieOptions` domain sharing.
