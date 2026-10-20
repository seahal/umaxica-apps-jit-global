# OIDC Exit Continuation POST Is Rejected With a Null Origin

Recorded 2026-10-20. Status: backlog. Observed in the local development log; no change has been
made.

## Problem

Auth's first-page Cancel or Switch returns to Base as a cross-site GET. Base answers with
`base/shared/authorization_exit_continuation.html.erb` (rendered by
`OidcAuthorizationResultPost#render_oidc_exit_continuation!`), whose form commits the exit through a
same-origin POST to the same path.

The template declares `<meta name="referrer" content="no-referrer">`. Under the Fetch Standard, a
non-GET/HEAD request issued from a document with the `no-referrer` policy serializes its `Origin`
header as `null`, even when the target is same-origin. Rails' origin-based forgery protection then
raises `ActionController::InvalidCrossOriginRequest`, handled by
`SignErrorResponses#handle_csrf_failure` as 422. The exit POST therefore cannot succeed from a real
browser.

## Observations

- `log/development.log` on 2026-10-20 showed `Base::App::Oauth::AuthorizationsController#show` with
  `switch_handoff` returning 200, followed by `#create` failing with "The browser returned a 'null'
  origin" and `Completed 422`, at least three times.
- The template was introduced in `87c15e1e5`.
- `test/integration/sign_entry_exit_flow_test.rb` and
  `test/integration/sign_entry_exit_com_org_flow_test.rb` exercise this flow. Integration tests do
  not send a browser-computed `Origin`, so they did not catch the rejection.

## Improvement direction

- Change the page's referrer policy to `same-origin` (meta tag or `Referrer-Policy` header). It
  still withholds the referrer from other sites, and same-origin POSTs carry a real `Origin`, so the
  origin check stays effective.
- Do not disable `forgery_protection_origin_check`; that weakens CSRF protection for every surface.
- Add a regression test that submits the continuation POST with the `Origin` header a browser would
  send under the page's declared policy, on each surface that renders the page (app, com, org).
- Check other no-referrer pages that contain a POST form (for example the sign-out notice pages
  using `SignOutNotice::SIGN_OUT_REFERRER_POLICY`) for the same defect.

## Addendum: referrer policy choice requires a security review

Added 2026-10-20. The `same-origin` direction above is superseded by this addendum and must not be
implemented without a security review.

The page's `no-referrer` policy is intentional: the GET URL that renders the page carries the
`switch_handoff` token in its query string, and `no-referrer` keeps that URL out of any `Referer`
header. Candidate policies differ as follows (per the Fetch and Referrer Policy specifications; not
yet verified in a browser):

| Policy                                                   | `Origin` on the same-origin POST     | `Referer` sent                                                       |
| -------------------------------------------------------- | ------------------------------------ | -------------------------------------------------------------------- |
| `no-referrer` (current)                                  | `null`, rejected by the origin check | none                                                                 |
| removed (site default `strict-origin-when-cross-origin`) | real origin                          | full URL including the token to same-origin targets                  |
| `same-origin`                                            | real origin                          | full URL including the token to same-origin targets; none cross-site |
| `strict-origin`                                          | real origin                          | origin only, never path or query                                     |

`strict-origin` is the current candidate: it keeps the token out of `Referer` and lets the origin
check pass. Removing the meta tag or using `same-origin` would place the token in request headers
that may reach logs or telemetry.

The review must confirm at least:

- The chosen policy never exposes `switch_handoff` (or `cancellation_ref`/`transaction_ref`) through
  `Referer`, logs or telemetry.
- `forgery_protection_origin_check` stays enabled. It is the control that rejects sibling-subdomain
  POSTs, because Rails' `header_or_legacy_token` strategy accepts `Sec-Fetch-Site: same-site`
  without a token.
- No alternative weakens CSRF protection: no `skip_forgery_protection`, no rescue of
  `InvalidCrossOriginRequest`, no acceptance of a `null` origin.
- Browser behavior is observed on each surface (app, com, org), not inferred from the specifications
  alone.
