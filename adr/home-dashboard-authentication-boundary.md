# Home and Dashboard Authentication Boundary

## Status

Accepted (2026-09-28). Supersedes `adr/base-warp-canonical-root-dashboard.md`.

## Amendment: Core dashboard presentation (2026-10-03)

In the target Core topology, TanStack Start owns Core's dashboard presentation. Rails retains
authentication, session processing, final authorization, and business logic under the Core
browser-to-Rails boundary in `adr/core-canonical-public-host.md`.

This presentation ownership decision applies only to Core. It imposes no dashboard framework,
rendering, or implementation-location requirement on Base, Warp, or any other surface. Each surface
retains its own applicable authentication and authorization contracts; the Base/Warp behavior below
continues to govern those surfaces independently of this Core presentation decision.

Core dashboard implementation and deployment remain deferred. This amendment records ownership, not
a completed migration or a change to the current route set.

## Amendment: anonymous Base Dashboard (2026-10-08)

Decided by the user on 2026-10-08. On Base (app, com, org) an anonymous `GET` or `HEAD /dashboard`
is no longer an ordinary 404. An HTML request is redirected to the surface's passive `/sign` page, a
JSON request is answered 401 without a location, and an Inertia request receives the existing 409
location response. Reaching `/sign` this way issues no admission and starts no sign-in flow. A
refused browser credential takes this same path after it is detached
(`adr/invalid-browser-credential-recovery.md`).

This partially supersedes the anonymous `/dashboard` cell of the table below and the sentence that
no redirect to sign-in is performed, for Base only. The authenticated Home 404, the absence of a
redirect between `/` and `/dashboard`, and the Warp contract are unchanged.

## Amendment: Global browser region canonicalization (2026-10-25)

The owner requested automatic `ri` insertion on Global browser URLs. Base Home and Dashboard now
use `PreferenceGlobal#set_region` for HTML navigation: missing or invalid region context is
canonicalized by a same-origin, same-path GET/HEAD redirect before the final page outcome. Valid
request context is preserved. Base JSON representations retain their existing in-request region
resolution. The table below describes the final response after canonicalization; the Home versus
Dashboard authentication boundary remains intact. Warp retains its Regional context behavior.
See `specs/global-region-canonicalization/spec.md` and `docs/architecture/preference.md`.

## Decision

Base and Warp apply the same contract on their app, com, and org hosts:

| Session       | `GET /`  | `GET /dashboard` |
| ------------- | -------- | ---------------- |
| Anonymous     | 200 Home | 404              |
| Authenticated | 404      | 200 Dashboard    |

No automatic redirect is performed between `/` and `/dashboard`, or from either page to sign-in. The
routes remain registered. A rejected request is expected control flow, not a failure: the action
renders the ordinary 404 representation itself through `SessionBoundaryNotFound` (the static public
404 page, or the `ActionDispatch::PublicExceptions` JSON document) instead of raising. The boundary
therefore never passes through the exceptions app, and `consider_all_requests_local` or
`show_exceptions` cannot change its outcome. Dashboard actions retain their surface authorization
checks. Both pages use the validated session state supplied by `logged_in?`.

The Home and Dashboard responses are private and not stored by shared caches. Public HTML 404
responses also carry `Cache-Control: private, no-store`, preventing an authenticated Home miss from
poisoning anonymous Home.

Successful direct sign-in returns to the surface's `/dashboard`, never through `/`. A protocol
continuation already in progress (OIDC authorization resume, a verified signed `pt`) keeps its own
destination. Every controller that completes a sign-in, including Base controllers such as the app
social completion, resolves its surface explicitly; a controller without a sign-in surface fails
instead of falling back to `/`. Successful sign-out returns to `/`. Authenticated Preference,
Switcher, Settings, and related return links target `/dashboard`.

## Consequences

Bookmarks and browser history that revisit a page outside its session state receive 404. The
ordinary error representation does not disclose the subject or reason for refusal.

## Regression record (2026-10-02)

`AuthenticationRedirects#sign_in_surface` recognized only the `Auth`, `Sign`, and `Acme` namespaces,
and `sign_in_dashboard_path` fell back to `"/"` for any other controller.
`Base::App::Social::Authentication::CompletionsController` therefore sent every ordinary Google and
Apple sign-in to `/`, which answers 404 for an authenticated session. Session-limit resolution was
unaffected because it names `/dashboard` directly. The surface now resolves `Base` as well, the
fallback is removed, and `test/integration/social_auth_login_test.rb` plus
`test/controllers/concerns/authentication_redirects_unknown_surface_test.rb` guard both halves.
