# OAuth 2.0 Demonstrating Proof of Possession (DPoP)

> **Partially superseded by the Acme / Sign / Core / Base / Palm boundary:** The DPoP vocabulary in
> this document remains useful as retained implementation detail. It must not assign token authority
> outside Acme, and it must not be treated as the default entry point for new Core, Base, or Palm
> flows.

## Specification

The DPoP implementation in this application is based on the following specifications:

- **RFC 9449 — OAuth 2.0 Demonstrating Proof of Possession (DPoP)**:
  <https://datatracker.ietf.org/doc/html/rfc9449>
- **RFC 7638 — JSON Web Key (JWK) Thumbprint**: <https://datatracker.ietf.org/doc/html/rfc7638>

## Purpose

DPoP binds access tokens to a client-generated asymmetric key pair. Even if an access token is
intercepted, it cannot be used without the corresponding private key. The client proves possession
of the private key by signing a DPoP proof JWT on each request.

## Design Decisions

- **JTI replay detection is not applied at the access token level.** DPoP proof validation on API
  requests is stateless (signature + htm + htu + iat + ath + cnf.jkt). No per-request database
  write. `Dpop::RequestVerifier` constructs `Dpop::ProofValidator` with `record_jti: false`, so the
  `jti` claim is still required but its uniqueness is not persisted.
- **JTI replay detection is applied to refresh token, step-up, login, and token-exchange
  operations.** These are low-frequency and security-critical, and call `Dpop::ProofValidator`
  directly with the default `record_jti: true`.
- **The replay store is relational, not Redis.** `Dpop::JtiReplayGuard` writes through
  `DpopProofStateable` to per-resource tables (`client_dpop_proof_states`,
  `operator_dpop_proof_states`, `visitor_dpop_proof_states`) with a 300-second TTL on `expires_at`.
  Expired rows are pruned by `DpopProofStatePurgeJob` (see Retention below).
- **This conforms to RFC 9449** where JTI checking is SHOULD, not MUST.
- **Supported algorithms:** ES256 and ES384 only (no RSA).
- **Adoption posture:** DPoP remains supported and maintained as optional proof-of-possession
  infrastructure. New product flows should not adopt it by default; before a flow depends on DPoP,
  review this implementation, the current OAuth/OIDC boundary, client key storage, nonce handling,
  and replay behavior.

## Implementation

Server-side DPoP support lives in flat `dpop_*.rb` files under `app/lib/` and `app/services/`:

| File                                            | Purpose                                               |
| ----------------------------------------------- | ----------------------------------------------------- |
| `app/lib/dpop_proof_verifier.rb`                | Core DPoP proof JWT validation (RFC 9449 Section 4.3) |
| `app/services/dpop_request_verifier.rb`         | Per-request DPoP verification orchestrator            |
| `app/services/dpop_jti_replay_guard.rb`         | RDB-backed JTI deduplication (stateful paths only)    |
| `lib/jit_security_jwt_thumbprint_calculator.rb` | RFC 7638 JWK Thumbprint and `ath` computation         |

Token issuance controllers (`Sign::App::TokensController`, `Sign::Org::TokensController`,
`Sign::Com::TokensController`) forward the `DPoP` proof header, request URI, and request method to
`Oidc::TokenExchangeService`. When validation succeeds, the issued access token and persisted token
row are both bound with `dpop_jkt`.

Primary login issuance also accepts an optional `DPoP` proof header. When present and valid,
`Authentication::Base#log_in` stores the proof key thumbprint on the token row and embeds the same
value in the issued JWT `cnf.jkt` claim.

Resource enforcement runs through `Authentication::CurrentResourceResolver` for Authorization-header
access. A token with `cnf.jkt` must be presented as `Authorization: DPoP <token>` with a matching
proof header. Presenting a DPoP-bound token as Bearer, omitting the proof, or sending a proof whose
`ath` does not match the access token fails authentication and returns a fresh `DPoP-Nonce` header
where the authentication pipeline can set one.

Token tables (`user_tokens`, `staff_tokens`, `customer_tokens`) store:

- `dpop_jkt` (string) — Base64url-encoded SHA-256 thumbprint of the client's public key

JWT access tokens include:

- `cnf.jkt` claim — the same thumbprint, embedded in the token for binding verification

## Proof Validation Steps

1. JWT header: `typ == "dpop+jwt"`, `alg` in {ES256, ES384}, `jwk` present (public key only)
2. Verify signature using the embedded `jwk`
3. `htm` matches HTTP method
4. `htu` matches HTTP URI (scheme + authority + path)
5. `iat` within acceptable time window
6. If access token provided: `ath == Base64url(SHA256(access_token))`
7. `cnf.jkt` in the access token matches the thumbprint of the proof's `jwk`

## Retention

JTI replay rows and issued nonces are short-lived. Each row carries `expires_at`
(`DpopProofStateable::TTL_SECONDS`, 300s). `DpopProofStatePurgeJob` deletes expired rows from
`client_dpop_proof_states`, `operator_dpop_proof_states`, and `visitor_dpop_proof_states` in
batches. It is scheduled from `config/recurring.yml` (`dpop_proof_state_purge`). These tables are
**not** covered by `RetentionPurgeJob`, which is keyed on `purge_eligible_at`, not `expires_at`.

## Current Adoption Posture

The current Acme / Sign / Core / Base / Palm boundary keeps DPoP available without making it a
preferred entry point. Existing server-side interfaces, token claims, persisted `dpop_jkt` fields,
proof-state tables, nonce/JTI services, cleanup jobs, and regression tests stay in place.

DPoP support being enabled does not by itself make a new flow approved to use it. Any future Core,
Base, Palm, iOS, Android, or other client implementation that wants to rely on DPoP must first
review the current implementation and threat model, then update the relevant ADR or plan with that
decision.

## Relationship to DBSC

DPoP and DBSC (W3C Device Bound Session Credentials) serve similar purposes but target different
flows:

| Mechanism | Flow                                | Binding target                     |
| --------- | ----------------------------------- | ---------------------------------- |
| DBSC      | Browser cookie-based sessions       | Session cookie bound to device key |
| DPoP      | API access via Authorization header | Access token bound to client key   |

DBSC is the active browser-session binding mechanism. DPoP remains available for
Authorization-header token binding where an explicitly reviewed flow chooses it. Palm does not use
DPoP today; it is bearer-only, and Palm access tokens carrying `cnf.jkt` must not be accepted as
plain Bearer tokens.

## VisitorAccount Token Strategy

Each client type uses a different combination of token transport and proof-of-possession mechanism,
based on its threat model:

| VisitorAccount | Access Token                                   | Refresh Token                | Proof-of-Possession                       |
| -------------- | ---------------------------------------------- | ---------------------------- | ----------------------------------------- |
| Rails HTML     | HttpOnly cookie                                | HttpOnly cookie              | DBSC                                      |
| Core browser   | HttpOnly cookie-carried JWT on Rails Core APIs | HttpOnly cookie              | DBSC where available                      |
| iOS / Android  | Acme-issued bearer token                       | Secure storage (Keychain/KS) | None by default; DPoP opt-in outside Palm |

**Notes:**

- `device_id` is a device identifier used for session management and token family tracking. It is
  not a proof-of-possession mechanism.
- DBSC binds cookies to a device key pair (proof-of-possession at the transport layer).
- DPoP binds bearer tokens to a client key pair (proof-of-possession at the application layer).

### Refresh Token Rotation Family

The primary defense against refresh token theft is **rotation family management** (RFC 6749 Section
10.4):

- Each refresh token use issues a new refresh token and invalidates the previous one.
- All tokens in a family share a `token_family` identifier.
- If a previously invalidated refresh token is presented (replay), the server revokes the entire
  family and forces step-up authentication.
- This detects token theft regardless of client type or transport mechanism.

Rotation family management is the core security invariant. DBSC and DPoP add defense-in-depth but
are not substitutes for rotation.

### Native App DPoP Readiness

Native apps (iOS / Android) do not require DPoP at this time. However, the server-side
infrastructure is designed to accept DPoP proofs from any client outside the Palm bearer-only
boundary:

- Token tables (`user_tokens`, `staff_tokens`, `customer_tokens`) already store `dpop_jkt`.
- `DPoP::ProofValidator` and `DPoP::RequestVerifier` are client-agnostic.
- The `cnf.jkt` claim in JWT access tokens works regardless of client type.

The current policy is **maintained optional DPoP** for native clients outside Palm:

- If a native client sends a DPoP proof header, the server validates it and enforces binding.
- If no DPoP proof is present, the server accepts the token as a standard Bearer token.
- Palm is excluded from this optional policy. Palm remains bearer-only until a separate ADR or plan
  changes that boundary.

Before native apps adopt DPoP, review the current DPoP implementation and threat model. If adopted,
the private key should be stored in platform secure hardware (iOS Secure Enclave / Android
Keystore). This prevents token exfiltration from being exploitable even if the access token itself
is leaked.

DPoP enforcement for native clients can be made mandatory in a future phase without server-side
changes.

## Related

- `docs/architecture/dbsc.md` — DBSC specification and implementation
- GitHub #573 — Original DPoP plan
- GitHub #731 — DPoP server-side implementation (DB + model + service)
- GitHub #732 — DPoP web-side design proposal (Next.js proof generation)
- GitHub #733 — OIDC standard endpoints
