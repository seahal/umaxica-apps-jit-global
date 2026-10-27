# RP grant stays alive after a sign-out cancelled at the OP

Status: Open. Accepted gap by the owner on 2026-10-26 (`one.md` D-188); revisit with WU-18
(`docs/backlog/2026-10-25-op-chain-runtime-role-removal.md`).

## What happens

Sign-out starts at an RP. The RP deletes its own cookies and session and redirects to the OP
`end_session_endpoint` (D-33 (2)). If the person cancels at the OP confirmation, or never answers it,
the OP stops nothing. The RP's grant and its refresh token then stay valid until they expire.

The refresh token was held only in the RP's browser cookie, which the RP has already deleted, so the
grant is usable only by someone who copied that cookie before the sign-out.

## Why it was accepted

- RP-Initiated Logout 1.0 sets no RP token revocation; RFC 9700 §4.14.2 places revocation on logout
  with the authorization server; Spring Security's OIDC logout handler only redirects.
- Calling the RFC 7009 revocation endpoint from the RP during sign-out (the withdrawn D-186) hits the
  endpoint's limit of 20 requests per minute per `remote_ip`, because every RP call comes from the
  server's own address, and holds a second Puma thread for the self-call.
- The previous direct OP database write by the RP contradicts G-16 ("RP never takes OP authority").

## Options when revisited

1. RFC 7009 call from the RP before the redirect, with the endpoint's rate limit keyed on the
   authenticated client instead of the address (needs a rate-limit decision, `ten.md` R-6).
2. A short grant lifetime for first-party RPs so the window closes by expiry.
3. Keep the gap.

## References

`one.md` D-33, D-186, D-188; `ten.md` §6 (D-5) and §8; `three.md` A14-6.
