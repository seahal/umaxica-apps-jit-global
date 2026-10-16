# Jump RP Routes and Continuation Page Redesign

Date: 2026-10-16

Status: Deferred. Neither item is implemented. Both wait for the upcoming breaking major update of
the OP/RP SSO system, so that the work is done once against the new contract instead of twice.

Related:

- `adr/jump-directed-rails-handoff-contract.md` — approved Jump edges; same-origin navigation does
  not use Jump
- `adr/secure-jump-link-redirector.md` — the gateway refuses an rt whose url origin equals its `iss`
- `adr/base-auth-ceremony-and-seven-rp-boundary.md` — the D-82 admission contract behind the
  continuation POSTs
- `test/integration/base_same_origin_handoff_test.rb` — the Base self-RP same-origin behavior

## 1. Record

On 2026-10-16 every sign-in started from a Base self-RP (`www.umaxica.{app,com,org}/sign`) failed.
Rails issued a Base-to-Base Jump rt for the start to `/oauth/authorize` and for the authorization
code return to `/oidc/callback`. The gateway rejected it (`jump_reject`, `reason: invalid_dst`,
`iss` equal to `dst_origin`), because the approved Jump graph has no self-loops.

The fix in the same change moved those same-origin hops off Jump:
`CommonRedirect#redirect_to_same_origin_or_jump_url` redirects by path when the target shares the
request origin, and the Base app, com and org sign entry, authorization code return, `prompt=none`
`login_required` return and session-limit code return opt into it. After the fix the repository
owner observed the Base app sign-in working in a browser, and Base com and org working with
redirect problems still present.

A walk through Cloudflare on the same day reached the Auth sign-in page from every `jp.*` and
`www-jp.*` RP, and a direct gateway probe accepted the Base-to-Core and Base-to-Warp callback
edges. The post-authentication half of those routes was not exercised, and the repository owner
reports that RP routes other than the Base self-RPs are still broken.

## 2. Jump routes for sign-up and sign-in

Treat the Base self-RP sign-up and sign-in Jump handling as reasonably correct, while acknowledging
the remaining redirect problems on Base com and org. Every other RP route (Core, Warp, Palm and the
remaining RP entries) is still broken.

When those routes are repaired, this section and the Base self-RP behavior it records are the
reference for the implementation:

- A navigation whose target shares the request origin (scheme, host and port) moves by path and
  never carries a Jump rt.
- A cross-origin navigation goes through Jump, and only along an approved edge in
  `JumpRtReturnPolicy::ALLOWED_EDGES`.
- The rt `url` claim is the next destination of the navigation. The page to return to after sign-in
  is the RP's session-held `pt`, not an rt.
- Each repair is verified end to end through the real gateway, including the post-authentication
  return to the RP callback, not only by Minitest.

## 3. Continuation page redesign

Sign-in reaches the Auth credential form only after about four Continue submissions (`POST /sign`,
the authorization ceremony start, `POST /ceremony_bindings` and the Base binding confirmation), and
more follow after authentication. The flow works, but a system that asks for this many Continue
actions has a definite design problem, and it needs a fundamental redesign rather than a local
patch.

Constraints that the redesign must keep:

- GET and HEAD create no ceremony state; state is created only by CSRF-, Origin- and
  Fetch-Metadata-protected POSTs.
- The D-82 entry, confirmation and redemption remain separate, browser-bound, non-authorizing
  steps. Their security rests on the browser nonce binding, not on a user click.

## 4. Order of work

1. Complete section 2 for every RP route.
2. Then redesign the continuation flow in section 3 at the Base level first, and propagate that
   design to every other surface and RP.

## 5. Reason for deferral

Neither item is implemented now because a breaking major update of the OP/RP SSO system is about to
be carried out. Both items are to be done against that new system.
