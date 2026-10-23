# OIDC Authorization Code Only: Implicit and Hybrid Flow Non-Adoption

## Status

**Accepted (2026-10-24).** Documentation-only owner decision. Extends the flow selection in
[OIDC Authorization Request Profile](oidc-authorization-request-profile.md), without superseding
its request, redirect, error, or registration contracts. No implementation change is authorized.

## Context

UMAXICA's OP and registered RPs use Authorization Code Flow with PKCE S256. That profile meets
current authentication requirements. The existing authorization request ADR already excludes
Implicit and Hybrid flows; this record owns the reasons for that exclusion and the conditions for
reconsidering it, rather than defining a second request-validation contract.

The `feature` worktree inspected for this decision contains the following implementation anchors:

- `app/values/oidc_discovery_document.rb` advertises only `response_types_supported: ["code"]`
  and `code_challenge_methods_supported: ["S256"]`.
- `app/resolvers/oidc_authorize_request_resolver.rb` accepts only `code`, requires S256 and a
  challenge, and validates the registered redirect URI, `state`, and `nonce`.
- `app/services/oidc_authorize_coordinator.rb` coordinates authorization-code issuance;
  `app/services/oidc_token_exchange_coordinator.rb` validates the code's client, redirect URI,
  and PKCE binding before issuing tokens.
- `app/values/oidc_client_registry.rb` owns registered clients and realm-specific redirect URIs.
  RP initiation in `app/controllers/concerns/oidc_sso_initiator.rb` selects Code with S256;
  `app/controllers/concerns/oidc_callback.rb` exchanges the code and validates the returned tokens,
  using the OP token verifiers and `app/values/oidc_pkce.rb` on the relevant boundaries.

Related authorize, token-exchange, and callback tests were inspected, not executed. These are static
observations of a worktree with existing uncommitted changes, not runtime or deployment acceptance.
The request-profile ADR's historical “not implemented” status is not a current verification result;
its Code/S256 decision agrees with these inspected paths.

## Decision

### D1. Authorization Code Flow with PKCE S256

UMAXICA MUST support `response_type=code` as its only OIDC authentication flow. Every client MUST
use PKCE with `code_challenge_method=S256`, including confidential clients. The authorization
response carries the authorization code and applicable protocol metadata, including `state` and
`iss`. ID Tokens and Access Tokens MUST be issued through the Token Endpoint after code exchange;
the authorization response MUST remain free of both token types.

Existing `state`, `nonce`, issuer, audience, signature, client, exact registered redirect URI,
transaction binding, and token validation requirements remain in force. PKCE supplements those
controls; it does not replace them.

### D2. Implicit Flow non-adoption

The supported response-type set excludes `id_token` and `id_token token`.

### D3. Hybrid Flow non-adoption

The supported response-type set excludes `code id_token`, `code token`, and `code id_token token`,
including equivalent orderings of those response-type combinations.

## Rationale

### Authorization Code Flow with PKCE

The current flow satisfies UMAXICA's needs while keeping token delivery at the Token Endpoint.
RFC 7636 §§4.2–4.6 defines challenge/verifier binding: S256-capable clients MUST use S256;
servers MUST implement S256, and verifier mismatch MUST yield `invalid_grant`.

RFC 9700 §2.1.1 requires public clients to use PKCE and authorization servers to support and enforce
it, including downgrade protection. PKCE is RECOMMENDED for confidential clients; with precautions,
they MAY instead use OIDC nonce. Non-verifier-exposing challenge methods are a SHOULD, currently
met by S256. Requiring PKCE S256 for every client is UMAXICA's stricter profile choice.

### Implicit Flow non-adoption

Code with PKCE already meets current requirements, so another authentication path has no present
benefit. Avoiding unused front-channel token delivery limits attack surface and verification work.

RFC 9700 §2.1.2 advises clients SHOULD NOT use authorization responses carrying Access Tokens unless
specified injection and leakage risks are mitigated, and SHOULD prefer token-endpoint delivery.
Its Access Token leakage/replay rationale applies to `id_token token`; `id_token` alone issues no
Access Token. Excluding the latter is UMAXICA's scope decision, not that Access Token warning.
PKCE protects code exchange; it neither directly protects Implicit Flow nor technically replaces it.

### Hybrid Flow non-adoption

UMAXICA has no requirement for an early ID Token or front-channel Access Token. Maintaining multiple
delivery paths would add integrity checks, tests, and operational complexity without a current use
case. OIDC Core §3.3 requires `c_hash` when an authorization-endpoint ID Token accompanies a code,
and `at_hash` when it also accompanies an Access Token, with corresponding validation.

Hybrid remains a formally defined OIDC flow. RFC 9700 §2.1.2 explicitly allows `code id_token` as an
example of token-endpoint Access Token delivery. Neither that RFC nor PKCE invalidates Hybrid as a
whole. Its exclusion here is a deliberate UMAXICA use-case choice.

## Alternatives Considered

- Add Implicit Flow for browser clients: current Code/S256 support meets their requirements.
- Add Hybrid Flow for early identity information: no current requirement justifies the additional
  token paths and integrity checks.
- Select flows per registered client or permit PKCE `plain`: additional profiles would expand
  configuration and verification work without a demonstrated need.

## Consequences

One authentication flow keeps implementation, testing, and operations bounded. Clients requiring
Implicit or Hybrid cannot integrate under this profile; they must use Code with S256 or await a
separate accepted decision. This record changes no code, registrations, routing, or stored data.
Back-Channel Logout, Dynamic Client Registration, and Pairwise Subject Identifiers are outside scope.

## Invariants

- Discovery MUST retain `response_types_supported: ["code"]` and
  `code_challenge_methods_supported: ["S256"]`.
- Authorization request handling MUST accept only `response_type=code` and require PKCE S256.
- The authorization response MUST deliver neither ID Tokens nor Access Tokens directly.
- Token issuance for this authentication flow MUST follow code exchange at the Token Endpoint
  with successful PKCE and existing client/redirect binding validation.
- Existing Authorization Code, Token Endpoint, Refresh Token, UserInfo, and Logout behavior and
  security controls remain unchanged. Refresh Token use is not an additional authentication flow.
- Admission of an external RP MUST preserve this profile unless a new accepted ADR changes it.

## Reconsideration Criteria

A new accepted ADR is required before adding a flow. It must evaluate a concrete use case unmet by
Code/S256, security requirements and threats, interoperability, and the additional validation,
testing, and operational burden. External RP admission alone does not reopen this decision.

## Related ADRs

- [OIDC Authorization Request Profile](oidc-authorization-request-profile.md): extended, not
  superseded; remains the owner of request-validation and error contracts.
- [Base/Auth ceremony and first-party RP boundary](base-auth-ceremony-and-seven-rp-boundary.md):
  preserves trust and state boundaries, including its recorded amendments.
- [OP/Auth/RP responsibility separation](op-auth-rp-authentication-responsibility-separation.md):
  authority placement evolves independently of the supported OIDC flow.
- [OIDC Claims Decision](oidc-claims-decision.md): preserves claims and token validation decisions;
  this record concerns flow selection, not a claims reconciliation.
- [OIDC RP Scope](oidc-rp-scope-umaxica-tlds-only.md): preserves current RP admission restrictions;
  future admission and flow expansion are separate decisions.
- [RP OIDC State and Return Target](rp-oidc-state-and-return-target.md): preserves RP transaction
  and return-target binding.

## References

- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0-final.html):
  §3.1 Authorization Code, §3.2 Implicit, §3.3 Hybrid; especially §§3.3.2.11–3.3.2.12 for hash checks.
- [RFC 7636 — Proof Key for Code Exchange](https://www.rfc-editor.org/rfc/rfc7636): §§4.2–4.6.
- [RFC 9700 — OAuth 2.0 Security Best Current Practice](https://www.rfc-editor.org/rfc/rfc9700):
  §§2.1.1–2.1.2.
