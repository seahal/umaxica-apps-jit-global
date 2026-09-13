# Social OmniAuth Callback Transport Implementation Notes

## Context

- Original plan: `plans/apple-google-external-authentication-architecture-audit.md`, Phase 5.
- Related decision: `adr/social-omniauth-callback-transport.md`.
- Implementation date: 2026-07-24.

## Decisions Made During Implementation

- Decision: use POST-only OmniAuth request phases and GET-only callbacks for both Apple and Google.
  - Why: the configured Apple `response_mode=query` has no scopes, and Google uses a browser
    redirect. OmniAuth's request phase is protected by the Rails CSRF form.
  - Alternatives considered: retain Apple POST as a compatibility path. Rejected because it leaves
    an unconfigured callback contract reachable.
  - Follow-up needed: changing Apple scopes or response mode requires a new provider contract review
    before changing routes.
- Decision: fix outbound `OmniAuth.config.full_host` to `PUBLIC_AUTH_SERVICE_URL`.
  - Why: an incoming Rack host can be the proxy's private origin and must not select the registered
    provider callback origin.
  - Alternatives considered: require the inbound host to equal the public origin. Rejected because
    the deployed proxy boundary intentionally presents a private host to Rails.
  - Follow-up needed: keep the exact public callback URLs registered in Apple and Google consoles.

## Deviations From Plan

- Change: existing Apple callback fixtures now include a refresh token.
  - Why: the already-approved Apple credential contract requires the callback adapter to receive a
    refresh token for later revocation handling.
  - Risk: fixture-only values do not prove the provider's production response.
  - Follow-up: Phase 1 real-Gem contract tests and controlled production E2E remain the release gate
    for Apple token behavior.

## Review Notes

- Tests run: focused Apple, social callback, route, controller, initializer, state, link, login, and
  robustness integration tests.
- Tests not run: full application test suite and controlled provider E2E.
- Documentation promotion needed: none; the durable transport decision is in the ADR.
