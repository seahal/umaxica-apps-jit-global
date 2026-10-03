# Home and Dashboard Authentication Boundary

## Status

Accepted (2026-09-28). Supersedes `adr/base-warp-canonical-root-dashboard.md`.

## Decision

Base and Warp apply the same contract on their app, com, and org hosts:

| Session | `GET /` | `GET /dashboard` |
|---|---|---|
| Anonymous | 200 Home | 404 |
| Authenticated | 404 | 200 Dashboard |

No automatic redirect is performed between `/` and `/dashboard`, or from either page to sign-in. The routes remain registered. A rejected request is expected control flow, not a failure: the action renders the ordinary 404 representation itself through `SessionBoundaryNotFound` (the static public 404 page, or the `ActionDispatch::PublicExceptions` JSON document) instead of raising. The boundary therefore never passes through the exceptions app, and `consider_all_requests_local` or `show_exceptions` cannot change its outcome. Dashboard actions retain their surface authorization checks. Both pages use the validated session state supplied by `logged_in?`.

The Home and Dashboard responses are private and not stored by shared caches. Public HTML 404 responses also carry `Cache-Control: private, no-store`, preventing an authenticated Home miss from poisoning anonymous Home.

Successful direct sign-in returns to the surface's `/dashboard`, never through `/`. A protocol continuation already in progress (OIDC authorization resume, a verified signed `pt`) keeps its own destination. Every controller that completes a sign-in, including Base controllers such as the app social completion, resolves its surface explicitly; a controller without a sign-in surface fails instead of falling back to `/`. Successful sign-out returns to `/`. Authenticated Preference, Switcher, Settings, and related return links target `/dashboard`.

## Consequences

Bookmarks and browser history that revisit a page outside its session state receive 404. The ordinary error representation does not disclose the subject or reason for refusal.

## Regression record (2026-10-02)

`AuthenticationRedirects#sign_in_surface` recognized only the `Auth`, `Sign`, and `Acme` namespaces, and `sign_in_dashboard_path` fell back to `"/"` for any other controller. `Base::App::Social::Authentication::CompletionsController` therefore sent every ordinary Google and Apple sign-in to `/`, which answers 404 for an authenticated session. Session-limit resolution was unaffected because it names `/dashboard` directly. The surface now resolves `Base` as well, the fallback is removed, and `test/integration/social_auth_login_test.rb` plus `test/controllers/concerns/authentication_redirects_unknown_surface_test.rb` guard both halves.
