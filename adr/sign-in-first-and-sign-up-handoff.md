# Sign In First: Sign Up Enters the Canonical Sign In Boundary

## Status

**Accepted (2026-10-18).** This ADR records the architecture and security rationale for the App and
Com registration handoff. It does not certify that every current route or abnormal path already
conforms.

## Decision

Sign In is UMAXICA's primary session-admission boundary. App and Com Sign Up keep independent
registration state machines for identity, contact proof, credential registration, and checkpoints,
but a completed registration does not issue a Browser or RP Session by itself. After durable
registration, the trusted, actor- and operation-bound result enters the ordinary Sign In admission.
That admission applies the same eligibility, guardrail, checkpoint, MFA, selector, cooldown,
session-limit, and finalization rules as an existing-user login.

The intended user experience remains automatic sign-in when the registration proof satisfies the
ordinary Sign In requirements. An additional challenge may still be required by those requirements.
The `COMPLETED` state of a Sign Up ticket is not itself a session grant.

Base remains the sole Browser Session and OIDC authorization authority. Auth verifies credentials,
records ceremony evidence, and returns a bound result; it does not create a general login session.
Each RP validates its own OIDC response and owns its local RP Session.

Once registration is durable, a later Sign In or Session issuance failure is a Sign In failure. It
must not delete, roll back, or anonymize the newly registered Identity as Sign Up compensation.
Duplicate finalization, stale tabs, superseded admissions, wrong-browser results, and replayed
handoffs must fail closed.

## Why the paths are asymmetric

Established identities may contain years of private data, credentials, permissions, relationships,
and business history. Keeping the strongest admission policy in one canonical Sign In boundary
reduces the risk that a future feature fixes MFA, cooldown, session limits, or refusal handling in
one login path while a parallel Sign Up issuer silently bypasses it. This prioritization does not
weaken registration validation: new accounts still require their own identity, contact, abuse,
credential, and eligibility controls.

Sharing helpers inside the canonical Sign In implementation is allowed. Giving Sign Up an
independent authority to call a common session writer is not; shared code is not shared policy.

## D06 and D13 are different transitions

User-initiated Sign In/Sign Up switching is allowed only on the initial selection page and must go
through Base for a fresh Admission. It is never an Auth-to-Auth shortcut, and it is forbidden after
the flow has progressed. A completed Sign Up's system-originated handoff into Sign In is a separate
terminal event and is not a user switch. `prompt=create` forbids the user's switch to Sign In, but
does not forbid the required post-registration handoff. `prompt=none` starts no interactive ceremony
and must produce only an OIDC success or standard error response.

## Consequences and review obligations

- Verify App email, telephone, Google, and Apple registration paths and Com email and telephone
  paths enter the same canonical Sign In policy before any session exists.
- Preserve actor, browser, registration operation, evidence, OIDC `state`, PKCE, `nonce`, and safe
  return-target bindings. Request parameters naming an actor or destination are not authorization.
- Test guardrail/MFA/checkpoint/selector/cooldown/session-limit refusal, duplicate finalize, replay,
  stale tabs, and Session issuance failure without deleting a durable Identity.
- Keep D11 (Org registration guidance), D12 (Org invitation admission), and D14 (distributed
  Cancel/Switch/Supersession/late-result coordination) unresolved until separately decided.

## Relationship to earlier decisions

This ADR clarifies the rationale of
[`sign-up-authentication-handoff-and-social-rt.md`](sign-up-authentication-handoff-and-social-rt.md)
and preserves the physical authority contract in
[`base-auth-ceremony-and-seven-rp-boundary.md`](base-auth-ceremony-and-seven-rp-boundary.md). It
does not authorize a route, schema, or session-issuer change by itself.

## E1 reference (Accepted 2026-10-21)

[Sign-up Flow Admission Binding and Cardinality](sign-up-flow-admission-binding-and-cardinality.md)
adds the APP/COM single Flow-to-Admission authority, parent-scoped concurrency, restart invariants,
and explicit Pending decisions. It preserves this ADR's Sign In First boundary and durable Identity
protection. Its accepted schema target is not implemented by this documentation update.
