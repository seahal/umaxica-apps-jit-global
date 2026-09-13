---
title: Route and Endpoint Inventory
status: draft
audience:
  - SIer
  - security-vendor
  - internal-architecture
  - implementation-team
owner: TBD
last-reviewed: TBD
source-of-truth: current-repository-evidence
confidentiality: internal-vendor-shareable
---

# Purpose

Inventory the current route families and their evident ownership.

# Scope

This is a human-readable inventory based on route files and route contract tests.

# Non-scope

This is not a full rack-aware route dump.

# Source Evidence

- `config/routes/acme.rb`
- `config/routes/sign.rb`
- `config/routes/core.rb`
- `config/routes/base.rb`
- `config/routes/palm.rb`
- `test/integration/routes/acme_route_contract_test.rb`
- `test/integration/routes/sign_route_contract_test.rb`
- `test/integration/routes/core_route_contract_test.rb`
- `test/integration/routes/base_route_contract_test.rb`
- `test/integration/routes/palm_route_contract_test.rb`
- `test/integration/routes/oidc_discovery_route_stability_test.rb`
- `test/integration/routes/route_target_contract_test.rb`

# Current Decisions

- `/oauth/*` is Acme-only.
- `/social/*` is not `/oidc/*`.
- RP callback is not social-provider callback.
- Route presence does not imply authority.

| Surface            | Route Family                  | Method                | Path Pattern                                                                                                     | Controller / Handler                                    | Purpose                                      | Authority                                                 | Evidence                                                                       | Notes                                                        |
| ------------------ | ----------------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- | -------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| Acme               | OAuth/OIDC protocol endpoints | GET/POST              | `/oauth/authorize`, `/oauth/token`, `/oauth/userinfo`, `/oauth/revoke`                                           | `acme/app/oauth/*`                                      | Authorization, token, userinfo, revocation   | Acme                                                      | `config/routes/acme.rb`, `test/integration/routes/acme_route_contract_test.rb` | Protocol surface.                                            |
| Acme               | OIDC RP endpoints             | GET                   | `/oidc/authorization`, `/oidc/callback`                                                                          | `acme/app/auth/*`                                       | RP initiation and callback                   | Acme for host-local RP flow; not social provider callback | `config/routes/acme.rb`, `test/integration/routes/acme_route_contract_test.rb` | RP-local flow on Acme host.                                  |
| Acme               | OIDC logout                   | GET/POST              | `/oidc/logout`                                                                                                   | `acme/app/oidc/logouts`                                 | Protocol logout                              | Acme                                                      | `config/routes/acme.rb`, `test/integration/routes/acme_route_contract_test.rb` | Acme-only.                                                   |
| Acme               | Social ceremonies             | POST                  | `/social/ceremonies/:id/continue`, `/social/ceremonies/:id/completion`                                           | `acme/app/social/authentications`                       | Social ceremony continuation/completion      | Sign ceremony UI; Acme final authority                    | `config/routes/acme.rb`, `test/integration/routes/acme_route_contract_test.rb` | Social route presence on Acme host exists in current routes. |
| Acme               | Sign-out                      | GET/POST              | `/sign/out/new`, `/sign/out/edit`, `/sign/out`, `/sign/out/complete`                                             | `acme/app/sign/outs`                                    | Browser logout ceremony                      | Acme                                                      | `config/routes/acme.rb`, `test/integration/routes/acme_route_contract_test.rb` | Canonical browser sign-out flow.                             |
| Acme               | Sign-in limitation            | GET/PATCH/DELETE      | `/sign/in/limitation`                                                                                            | `acme/app/sign/in/limitations`                          | Session-limit resolution                     | Acme                                                      | `config/routes/acme.rb`, `test/integration/routes/acme_route_contract_test.rb` | Session-limit ceremony.                                      |
| Acme               | Verification                  | GET/POST              | `/verification`, `/verification/completion`, `/verification/cancellation`                                        | `acme/app/verifications`                                | Verification ceremony                        | Acme                                                      | `config/routes/acme.rb`, `test/integration/routes/acme_route_contract_test.rb` | Step-up / ceremony completion boundary.                      |
| Sign               | Sign-in                       | GET/POST/PATCH        | `/sign/in`, `/sign/in/email`, `/sign/in/passkey/*`, `/sign/in/challenge/*`, `/sign/in/session`, `/sign/in/check` | `sign/app/sign/in/*`                                    | Credential ceremonies                        | Sign                                                      | `config/routes/sign.rb`, `test/integration/routes/sign_route_contract_test.rb` | Ceremony UI.                                                 |
| Sign               | Sign-up                       | GET/POST/PATCH        | `/sign/up`, `/sign/up/*`                                                                                         | `sign/app/sign/up/*`                                    | Sign-up ceremonies                           | Sign                                                      | `config/routes/sign.rb`, `test/integration/routes/sign_route_contract_test.rb` | Email, telephone, and social sign-up routes.                 |
| Sign               | Social                        | GET/POST              | `/social/google/sign/in`, `/social/apple/sign/in`, `/social/*/sign/up`, callbacks                                | `sign/app/social/*`, `sign/app/auth/omniauth_callbacks` | Social sign-in/sign-up and callback handling | Sign ceremony UI; not authorization server                | `config/routes/sign.rb`, `test/integration/routes/sign_route_contract_test.rb` | Settings link/unlink uses provider settings routes.          |
| Sign               | Settings / credentials        | GET/POST/PATCH/DELETE | `/settings`, `/settings/*`                                                                                       | `sign/app/settings/*`                                   | Session and credential management UI         | Sign UI; Acme authority for session/token decisions       | `config/routes/sign.rb`, `test/integration/routes/sign_route_contract_test.rb` | UI host is not authority.                                    |
| Sign               | Sign-out                      | GET/POST              | `/sign/out/new`, `/sign/out/edit`, `/sign/out`, `/sign/out/complete`                                             | `sign/app/sign/outs`                                    | Browser logout ceremony                      | Sign UI; Acme authority for direct mutation               | `config/routes/sign.rb`, `test/integration/routes/sign_route_contract_test.rb` | Confirmation and completion pages are hosted on Sign.        |
| Core               | API                           | GET/PATCH/POST        | `/api/v0/*`                                                                                                      | `core/app/*`                                            | Cookie/theme/DBSC/session/refresh            | Core BFF surface; Acme authority for tokens               | `config/routes/core.rb`, `test/integration/routes/core_route_contract_test.rb` | Preference endpoints live under `/api/v0/preferences/*`.     |
| Core               | OIDC                          | GET                   | `/oidc/authorization`, `/oidc/callback`, `/oidc/backchannel/logout`                                              | `core/app/auth/*`, `core/app/oidc/backchannel/logouts`  | RP start, callback, backchannel logout       | Core RP/BFF                                               | `config/routes/core.rb`, `test/integration/routes/core_route_contract_test.rb` | RP callback is not social callback.                          |
| Core               | Sign-out                      | GET/POST              | `/sign/out/new`, `/sign/out/edit`, `/sign/out`, `/sign/out/complete`                                             | `core/app/sign_outs`                                    | Browser logout ceremony                      | Core UI; Acme authority                                   | `config/routes/core.rb`, `test/integration/routes/core_route_contract_test.rb` | Canonical browser sign-out flow.                             |
| Base               | OIDC                          | GET                   | `/oidc/authorization`, `/oidc/callback`                                                                          | `base/*/auth/*`                                         | RP start and callback                        | Base RP/BFF                                               | `config/routes/base.rb`, `test/integration/routes/base_route_contract_test.rb` | Base control-plane surface.                                  |
| Base               | Sign-out                      | GET/POST              | `/sign/out/new`, `/sign/out/edit`, `/sign/out`, then `303` `/lobby`                                               | `base/*/sign_outs`, `base/*/lobbies`                    | Browser logout ceremony                      | Base UI; Acme authority                                   | `config/routes/base.rb`, `test/integration/routes/base_route_contract_test.rb` | Completes on Base `/lobby`; `/sign/out/complete` is not a Base route. |
| Palm               | OIDC                          | GET                   | `/oidc/authorization`, `/oidc/callback`                                                                          | `palm/app/auth/*`, `palm/app/oauth/callbacks`           | Native client login/callback compatibility   | Palm client surface                                       | `config/routes/palm.rb`, `test/integration/routes/palm_route_contract_test.rb` | Callback naming is compatibility-only.                       |
| Palm               | Native API                    | GET                   | `/api/v0/profile`                                                                                                | `palm/app/api/v0/profiles`                              | Native profile                               | Palm                                                      | `config/routes/palm.rb`, `test/integration/routes/palm_route_contract_test.rb` | Native/API client surface.                                   |
| Help / Docs / News | Content surfaces              | Various               | See respective route files                                                                                       | Various                                                 | Non-identity content delivery                | Not part of identity authority                            | `config/routes/help.rb`, `config/routes/docs.rb`, `config/routes/news.rb`      | Included only if relevant.                                   |

# Contradictions

- `config/routes/acme.rb` and `test/integration/routes/acme_route_contract_test.rb` show social
  ceremony routes on Acme host, while higher-level identity docs describe Sign as the social
  ceremony UI and Acme as the final authority. This is a UI-vs-authority distinction, not a route
  ownership contradiction.
- Some route names and controller namespaces retain historical `sign` and `acme` vocabulary that
  does not map 1:1 to current authority decisions.

# Open Questions

- Whether all current social route placements are long-term or compatibility placements.
- Whether Palm callback naming remains stable or is only compatibility surface.

# Related Documents

- `docs/vendor/identity/01_current-architecture.md`
- `docs/vendor/identity/02_responsibility-boundary.md`
- `docs/vendor/identity/04_cookie-session-token-matrix.md`
- `docs/vendor/identity/05_authentication-flow-inventory.md`
