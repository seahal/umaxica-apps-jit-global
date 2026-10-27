# Back-channel logout cannot be delivered in development

Status: Open, deferred by the owner on 2026-10-27 (sign-out acceptance is revisited later).

## Observation

During the owner's manual APP check on 2026-10-27, Visa's sign-out committed (`LOGGED_OUT` audit,
return through Jump to `https://www.umaxica.app/sign/out/completion`, 200), but every Logout Token
delivery ended with `oidc.backchannel_logout.delivery` `outcome: "invalid_endpoint"`, which
`OpOutboxDispatchJob` treats as permanent.

## Cause

`OidcBackchannelLogoutClient` builds its connection with `require_https: true` and
`require_public_address: true`. In the development container the first-party RP names resolve to the
container's private address through compose network aliases (`.devcontainer/compose.yaml`), so the
public-address guard refuses the endpoint before any request. Production RPs are expected to resolve
to public addresses; this was not verified.

## Effect

The browser's own RP clears itself before redirecting (D-33 (2)), so the visible sign-out works.
Other RPs signed in from the same browser are not notified in development, and BCL delivery cannot
be checked by hand there.

## Options (not decided)

1. Record development as unable to verify BCL and rely on automated tests.
2. In local environments only, send to first-party RP hosts over `http://<host>:<PORT>` and allow the
   private address, as `OutboundHttp::LocalBackChannel` does for OP and authority calls. This adds an
   exception to the SSRF guard and needs an explicit decision.
