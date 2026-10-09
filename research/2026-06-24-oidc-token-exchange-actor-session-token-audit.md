# OIDC token exchange actor-session audit

Date: 2026-06-24

This memo records the confirmed pre-change behavior for the Acme actor-session / OIDC token-exchange
defect.

## Confirmed root-token creation paths

- Browser login/session establishment creates the actor session root through
  `AuthenticationBase#log_in`, `issue_login_tokens_within_lock`, `with_actor_session_lock`, and
  `create_login_token_record`.
  - `app/controllers/concerns/authentication_base.rb:347-368`
  - `app/controllers/concerns/authentication_base.rb:459-514`
  - `app/controllers/concerns/authentication_base.rb:1929-1946`
- OIDC authorization-code exchange separately creates a new root token record and writes
  OIDC-specific state directly onto it.
  - `app/services/oidc_token_exchange_service.rb:138-260`

## Session-limit bypass

- The browser login path is serialized by `with_actor_session_lock` and routed through the
  session-limit checks in `issue_login_tokens_within_lock`.
  - `app/controllers/concerns/authentication_base.rb:363-368`
  - `app/controllers/concerns/authentication_base.rb:459-489`
- The OIDC token exchange path does not call `log_in`, `with_actor_session_lock`,
  `SignInSessionLimitManager`, or `create_login_token_record`. It writes `ClientToken`,
  `OperatorToken`, or `VisitorToken` directly.
  - `app/services/oidc_token_exchange_service.rb:138-260`
- The authorization-code issuance helper also does not bind the code to a specific root token row.
  - `app/services/oidc_authorization_code_issuer.rb:42-45`
  - `app/models/client_authorization_code.rb:38-78`
  - `app/models/operator_authorization_code.rb:38-78`
  - `app/models/visitor_authorization_code.rb:38-78`

## Missing authorization-code session reference

- The authorization-code tables currently store `user_id`, `staff_id`, or `visitor_id`, plus the RP
  `client_id`, but no foreign key to the exact actor-session root that authorized the code.
  - `app/models/client_authorization_code.rb:4-30`
  - `app/models/operator_authorization_code.rb:4-30`
  - `app/models/visitor_authorization_code.rb:4-30`
- The issuer only persists the actor and RP request parameters.
  - `app/services/oidc_authorization_code_issuer.rb:42-45`
  - `app/services/oidc_authorization_code_issuer.rb:76-88`

## Logout and revocation consequences

- OIDC logout currently resolves and revokes by root token `public_id`, `device_session_id`, or
  `oidc_sid`, so one browser/device root can be found through multiple fallback paths.
  - `app/controllers/concerns/sign_oidc_logout.rb:280-330`
- RP access-token validation also resolves by `sid` directly to the root token table.
  - `app/services/oidc_access_token_authenticator.rb:81-109`
  - `app/controllers/concerns/authentication_current_resource_resolver.rb:126-177`
- RP token revocation follows the same root-token lookup pattern.
  - `app/services/oidc_token_revocation_service.rb:34-96`
- The current OIDC callback writes `oidc_sid` and `oidc_client_id` onto the root token row after
  login.
  - `app/controllers/concerns/oidc_callback.rb:118-126`
- Result: one browser/device login can fan out into multiple independent root rows, logout may
  revoke only one row, and OIDC state remains tied to the root token instead of a separate RP usage
  record.

## Test gaps

- I did not find dedicated coverage for:
  - exact root-session binding on authorization-code issuance
  - preventing OIDC exchange from minting a new root token
  - usage-level RP state separation
  - DB-backed cascade deletion from root token to RP usage rows
  - cascade logout run/continuation behavior
- Existing tests are centered on the current root-token model and the current logout/revocation
  behavior, not the target usage model.
  - `test/services/oidc/token_exchange_service_test.rb`
  - `test/controllers/concerns/sign_oidc_logout_test.rb`
  - `test/services/oidc_access_token_authenticator_test.rb`
  - `test/services/oidc_token_revocation_service_coverage_test.rb`

## Environment and schema notes

- Rails: `8.2.0.alpha`
- Ruby: `4.0.5`
- PostgreSQL: `17.10`
- The repo uses separate ticket databases for app/org/com, so the root token tables live in
  different physical databases:
  - app: `app_ticket`
  - org: `org_ticket`
  - com: `com_ticket`
- `public_id` is already a NanoID-style 21-character identifier in the shared `PublicId` concern.
  - `app/models/concerns/public_id.rb:4-17`

## Current contract summary

- Root token tables already carry OIDC protocol state directly (`oidc_client_id`, `oidc_sid`,
  `oidc_jti`, `oidc_scope`).
  - `app/models/client_token.rb:21-38`
  - `app/models/operator_token.rb:21-38`
  - `app/models/visitor_token.rb:21-38`
- The access-token JWT contract currently reuses the root token public id as both
  `session_public_id` and `sid` in the browser helper path.
  - `app/controllers/concerns/authentication_jwt_tokens.rb:7-38`
- The token resolver still treats `sid` as a lookup key for the root token row.
  - `app/controllers/concerns/authentication_current_resource_resolver.rb:126-177`
