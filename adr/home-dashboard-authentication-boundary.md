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

## Amendment: authenticated Home is refused with 403 (2026-11-03)

Decided by the owner on 2026-11-03. An authenticated `GET /` on Base and Warp (app and org) is
answered 403, not 404, and still never redirects. The page exists and is denied to that session, so
a not-found answer misdescribes it. JSON receives `{"status":403,"error":"Forbidden"}`; other
requests receive the `errors.messages.not_authorized` text as plain text. Both carry
`Cache-Control: private, no-store`.

The anonymous `/dashboard` cells, the Base anonymous redirect amendment and the absence of any
redirect between `/` and `/dashboard` are unchanged. Warp and Base `com` were not touched by this
change; `com` has no Home controller using this boundary in the current tree (unverified).

## Amendment: Global browser region canonicalization (2026-10-25)

The owner requested automatic `ri` insertion on Global browser URLs. Base Home and Dashboard now use
`PreferenceGlobal#set_region` for HTML navigation: missing or invalid region context is
canonicalized by a same-origin, same-path GET/HEAD redirect before the final page outcome. Valid
request context is preserved. Base JSON representations retain their existing in-request region
resolution. The table below describes the final response after canonicalization; the Home versus
Dashboard authentication boundary remains intact. Warp retains its Regional context behavior. See
`specs/global-region-canonicalization/spec.md` and `docs/architecture/preference.md`.

## Amendment: RP Home and post-sign-in landing (2026-11-07)

By the owner's decision, Base app/org, Palm app, and Warp app/org keep an anonymous Home available
and answer an authenticated request to `/` with 403, no redirect, and `Cache-Control: private,
no-store`. Invalid or expired RP sessions are treated as signed out. After a successful OIDC callback,
those RPs use their own `/dashboard` when the validated `target_link_uri` is absent or invalid. A
validated target continues to take precedence. Base retains its existing selector flow after landing
on `/dashboard`.

Core app/org are the explicit exception: their roots continue to render for signed-in and signed-out
visitors, and a callback without a validated target lands on `/`. Core has no Rails dashboard; its
screens are shared with the TanStack Start frontend, so the root remains its entry point.

The signed-out Dashboard behavior remains a documented residual: Base and Palm redirect to their
own `/sign` entry with the Dashboard path as the target, while Warp returns 404. This amendment does
not change that difference, `/sign`, or CSRF configuration.

## Decision

### Persona selection and switching (2026-11-06)

During sign-in, a single eligible persona is selected automatically. If multiple personas are
eligible, the sign-in completes and Base `/selector` records one selection per RP session. A
selected session cannot write another selector choice; later changes go through `/switcher` only.
The selector remains outside the sign-in state machine for now; connecting it is tracked in
`plans/backlog/2026-11-06-selector-state-machine-connection.md`.

The active Home and Dashboard contracts are:

| Surface      | Session       | `GET /`              | `GET /dashboard`                                  |
| ------------ | ------------- | -------------------- | ------------------------------------------------- |
| Base app/org | Anonymous     | 200 Home             | Redirect to `/sign` with the Dashboard as target  |
| Base app/org | Authenticated | 403, no redirect     | 200 Dashboard or selector flow                   |
| Palm app     | Anonymous     | 200 Home             | Redirect to `/sign` with the Dashboard as target  |
| Palm app     | Authenticated | 403, no redirect     | 200 Dashboard                                     |
| Warp app/org | Anonymous     | 200 Home             | 404                                               |
| Warp app/org | Authenticated | 403, no redirect     | 200 Dashboard                                     |
| Core app/org | Either        | 200 shared Home      | No Rails Dashboard route                         |

Base com routes were removed; no Base com Home or Dashboard contract remains. No redirect connects
Home with Dashboard. The signed-out Dashboard difference is retained: Base and Palm redirect to
their own `/sign` entry with the Dashboard path as target, while Warp returns 404. A refused signed-in
Home request on Base, Palm, or Warp is expected control flow and returns 403 with
`Cache-Control: private, no-store`; invalid or expired RP credentials follow the signed-out row.
Dashboard actions retain their surface authorization checks.

Responses whose outcome depends on RP authentication state are not stored by shared caches. Public
HTML 404 responses also carry `Cache-Control: private, no-store`.

Successful direct sign-in returns to the surface's `/dashboard`, never through `/`, on Base and
Warp app/org and Palm app. Core app/org retain their explicit `/` exception above. A protocol
continuation already in progress (OIDC authorization resume, a verified signed `pt`) keeps its own
destination. Every controller that completes a sign-in, including Base controllers such as the app
social completion, resolves its surface explicitly; a controller without a sign-in surface fails
instead of falling back to `/`. Successful sign-out returns to `/`. Authenticated Preference,
Switcher, Settings, and related return links target `/dashboard`.

## Consequences

Bookmarks and browser history follow the surface-specific rows above when the session changes. The
ordinary refusal representations do not disclose the subject or reason for denial.

## Regression record (2026-10-02)

`AuthenticationRedirects#sign_in_surface` recognized only the `Auth`, `Sign`, and `Acme` namespaces,
and `sign_in_dashboard_path` fell back to `"/"` for any other controller.
`Base::App::Social::Authentication::CompletionsController` therefore sent every ordinary Google and
Apple sign-in to `/`, which answers 404 for an authenticated session. Session-limit resolution was
unaffected because it names `/dashboard` directly. The surface now resolves `Base` as well, the
fallback is removed, and `test/integration/social_auth_login_test.rb` plus
`test/controllers/concerns/authentication_redirects_unknown_surface_test.rb` guard both halves.
