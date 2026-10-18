# Auth Boundary And Step-Up Hardening

This implementation slice makes the highest-risk pre-deploy behavior fail closed.

- `:open` authentication is anonymous only when credentials are absent. Presented but invalid
  credentials must not fall back to anonymous.
- Step-Up requirements are represented as `StepUp::Requirement`; runtime satisfaction must check
  scope, AAL, method, TTL, token binding, and session binding.
- New credential registration updates method availability and audit state only. It must not write
  token Step-Up freshness.
- Jump URL `rt` is a signed redirect token boundary. Raw `return_to`, `redirect_uri`, or external
  URL values must not be copied into `?rt=`.
- OAuth/OIDC token endpoints are protocol endpoints, not social-login browser actions. They use
  client authentication / PKCE / rate-limit / no browser session mutation boundaries.

Remaining follow-up:

- Finish decomposing `Authentication::Base`; this slice only moved the riskiest checks to stricter
  resolver/requirement boundaries.
- Once the JWT registry test configuration is repaired, run the full auth/security narrow suite and
  update any tests that were still creating legacy Step-Up freshness with only timestamp and scope.
