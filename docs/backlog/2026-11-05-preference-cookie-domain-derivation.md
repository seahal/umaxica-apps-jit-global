# Preference cookie Domain derived from the request host

Status: Proposed on 2026-11-05. Not yet triaged. The owner asked for a decision on whether this
derivation needs remediation; no code change is authorized by this note.

## Observation

The anonymous Preference cookies are the only cookies this application writes with a `Domain`
attribute. The attribute comes from one method,
`app/controllers/concerns/preference_access_token_issuer.rb:88` (`anonymous_com_cookie_domain`),
which takes the last two labels of `request.host` and returns `nil` (host-only) when the host has
fewer than three labels.

It is applied through `anonymous_com_cookie_options` to `__Secure-preference` (httponly), `language`
and `__Secure-experience` (both readable by JavaScript), with a 400-day lifetime, at three write
sites:

- `app/controllers/concerns/preference_access_token_issuer.rb:65-70` (`emit_anonymous_com_token!`)
- `app/controllers/concerns/preference_write_boundary.rb:770-775` (`emit_anonymous_realm_token!`,
  through `anonymous_realm_cookie_options`)
- `app/controllers/base/com/application_controller.rb:142-145` (display repair)

All other cookie writers, including the session, authentication, OIDC RP, ceremony and binding
cookies, set no `Domain` (`app/values/core_cookie_options.rb:4`,
`lib/jit_session_cookie_config.rb`).

## Concerns to assess

1. **Public suffix blindness.** "Last two labels" equals the registrable domain only for
   single-label public suffixes such as `.com`. A host under a multi-label suffix (for example
   `example.co.jp`) yields `.co.jp`, which browsers reject; the cookies would then be dropped
   silently. An IP-literal host would yield a meaningless value such as `.0.5`.
2. **Request-derived scope.** The scope comes from the `Host` header rather than configuration.
   Production restricts `config.hosts` (`config/environments/production.rb:153-158`), which bounds
   this today; the derivation itself carries no allowlist and depends on that setting remaining
   strict in every environment that serves these cookies.
3. **Sharing breadth.** Every subdomain under the derived domain, including any future or
   third-party-operated subdomain, can read the JavaScript-readable cookies and receives all three.
   Whether that breadth matches the intended realm needs confirmation.
4. **Stale references.** `adr/cookie-domain-scope-by-surface.md` cites `Core::CookieDomain` and
   `app/services/core/cookie_options.rb`; `app/services/core/` no longer exists. Method and comment
   names still say `com` while surrounding uncommitted work moves to `realm` naming.

## Options

1. Keep the derivation and record the accepted constraints: single-label public suffixes only and
   reliance on `config.hosts`.
2. Configure the shared cookie domain explicitly per realm (required `ENV.fetch` or boot config) and
   fail when the request host is not under it.
3. Make these cookies host-only like every other cookie, if realm-wide sharing is not required.

## Acceptance when resumed

- Decide whether realm-wide sharing is required and which hosts form each realm.
- Cover hosts below, at and above the three-label threshold, `localhost`, IP literals and a
  multi-label public suffix; verify the emitted `Set-Cookie` attributes.
- Update `adr/cookie-domain-scope-by-surface.md` and `docs/security/cookie-domain-scope.md` to match
  the decision.

## Basis

Static reading at `b30345216886c98af1f04cbd434f067f12decf01` with uncommitted changes present in the
touched Preference files. No tests, browser checks or deployed-host checks were run.
