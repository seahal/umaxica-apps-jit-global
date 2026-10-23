# OIDC Authorization Request Profile

## Status

**Accepted (2026-10-23), not implemented.** Owner decisions D-145, D-146, D-147, D-148, D-149 of the
2026-10 authentication cycle; implementation in its work units WU-42 and WU-43.

Flow-selection rationale and reconsideration criteria are extended by
[OIDC Authorization Code Only](oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md)
(Accepted 2026-10-24). This ADR continues to own request-validation and error contracts.

## Decision

1. **Required request parameters:** `response_type=code` (no implicit or hybrid), `client_id`,
   `redirect_uri`, `scope` containing `openid`, `state`, `nonce`, `code_challenge`,
   `code_challenge_method=S256`. Requiring `state` and `nonce` is a UMAXICA profile restriction the
   specifications permit; every RP is first-party.
2. **`redirect_uri`** (OIDC Core 1.0 §3.1.2.1, RFC 6749 §3.1.2, RFC 9700 §2.1, §4.1): compared with the
   URIs registered for the `client_id` by simple string comparison — no prefix, suffix, wildcard,
   normalization or added query. A missing, unregistered or mismatched `redirect_uri`, or an unknown
   `client_id`, is refused locally and **no error is redirected to it** (RFC 6749 §3.1.2.4,
   §4.1.2.1). The authorization code is bound to `client_id` and `redirect_uri`; the token endpoint
   requires the same value.
3. **Errors after a valid client and `redirect_uri`** are returned to the registered `redirect_uri`
   with `error`, optional `error_description`, `state` when the request carried one, and `iss`
   (RFC 6749 §4.1.2.1, OIDC Core §3.1.2.6, RFC 9207). The registered URI is kept as is and response
   parameters are appended to any registered query.
4. **`prompt`:** Discovery advertises `prompt_values_supported` per realm — APP/COM `none`, `login`,
   `create`; ORG `none`, `login`. An unsupported value or any combination of values gets a direct
   HTTP 400 `invalid_request` naming `prompt` (Prompt Create 1.0 §4.1); this is the one exception to
   point 3.
5. **Token endpoint:** a `redirect_uri` or client mismatch and a `code_verifier` that does not match
   the stored challenge are `invalid_grant` (RFC 6749 §5.2, RFC 7636 §4.6); a missing
   `code_verifier` is `invalid_request`. A malformed `code_challenge` (not 43 base64url characters)
   is `invalid_request`.
6. **Registration-time validation:** every registered `redirect_uri` is absolute, has no fragment,
   uses TLS for web RPs and carries no reserved query key (UMAXICA hardening). A doubtful
   registration fails the boot.
7. **Accepted risk:** whether a Jump-forwarded authorize request keeps `redirect_uri` byte-identical
   is judged in the Jump integration test; until then exact matching refuses any altered value, so
   the residual is a failed sign-in, never a wrong delivery.

## References

- [RP OIDC state and return target](rp-oidc-state-and-return-target.md)
- [OIDC RP scope](oidc-rp-scope-umaxica-tlds-only.md)
