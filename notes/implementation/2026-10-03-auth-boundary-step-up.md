# Authentication boundary and step-up implementation context

On 2026-10-03 the user directed the OTP delivery-event/DEBUG disclosure to be escalated and
resolved comprehensively. The previously isolated logging proposal is deferred to the mandatory
[active remediation plan](../../plans/active/otp-observability-secret-exposure-remediation.md)
and [accepted handling ADR](../../adr/otp-observability-secret-exposure-remediation.md).
This supersedes the note's earlier description of awaiting approval for that isolated proposal;
it does not mark the exposure fixed or authorize an event format. The remediation remains open.

The conversation's R01–R16 ledger is the implementation scope. Related decisions are `adr/root-login-establishment-boundary.md` and `adr/base-auth-ceremony-and-seven-rp-boundary.md`. The ledger is not complete.

The user approved additive actor-specific flow evidence/result fields, preserved sign-in authentication context, Auth admission purpose and exclusive transaction references, durable step-up result generation/state, exact verified credential references, and public challenge fields on existing step-up sessions. The user also approved reusing the existing PasskeyAuthenticationPanel transport and making Base verification GET a confirmation page followed by CSRF-protected POST admission. Do not request those approvals again.

Local sign-in now returns Auth evidence through an opaque result to Base's existing root issuance function. ORG Emergency evidence preserves Emergency context. Transport acceptance has a short deadline; a result already accepted by Base into the existing session-limit pending flow uses that flow's deadline and original authentication event during remediation. It does not promote a stale timestamp to the current time. This distinction is recorded in the root-login ADR.

Phase two has additive ticket storage and model/write boundaries in place. BaseStepUpAdmissionIssuer retains a specific transaction, deadline and attempt count across repeated starts. Opaque admission/result resolution uses the actor-specific step-up table and exact purpose instead of OIDC lookup. DB-backed Passkey challenge methods use session-to-transaction lock order, preserve the challenge deadline, and burn a matching reference before reporting an origin or expiry mismatch. Signature verification callers must perform this consumption as its own committed ticket operation before a later verification/finalization transaction; an enclosing transaction that rolls back could otherwise undo the burn.

Base confirmation/POST start, scoped Auth admission, Passkey POST options and real assertion verification, opaque result return, and atomic Base freshness completion are connected. An APP HTTP integration starts from an actual Base-issued root cookie, completes a signed Passkey assertion on Auth without root cookies, and returns to the protected birthdate page. Jump and Turnstile are stubbed; this is not a real-browser result. COM/ORG independent complete journeys remain outstanding. Legacy JWT and CookieStore callers outside this new path still require retirement; signup, MFA, settings, cancellations and invalidations remain incomplete.

The approved APP/COM Email OTP columns and encrypted Noticed job payload are implemented. Issuance uses the existing 60-second step-up resend interval. Verification uses the existing five-attempt, fifteen-minute lockout policy, with credential-scoped counters that survive resend and replacement transactions. Ticket proof is one-time and does not itself grant Base freshness. Delivery checks the exact transaction, recipient and code generation on writers before SMTP and records the current generation's outcome. SMTP runs outside database locks; cancellation or resend after that check can prevent proof acceptance but cannot recall an already-sent email. APP/COM display, issuance, verification and redelivery now use that admitted DB context; actual delivery and fault coverage remain outstanding. The user asked for clarification, rather than approving the proposed delivery-event redaction; that shape change is still pending.

The user deferred the proposed APP Email JSON success format change. Its current success renderer
expects token data and is not suitable for Auth evidence-only completion. Leave this as an explicit
unresolved contract; do not restore Auth root issuance or silently claim this path works. The full
Ruby regression run also exposed old admission-free Auth tests and continuation expectations. They
need purpose-correct setup and assertions, while real implementation failures still require fixes.

Tests must run sequentially at the command level because the repository test harness clones shared PostgreSQL databases. Concurrent Rails commands caused a source-database-in-use setup error; sequential rerun passed. Individual tests may still use the existing independent-connection concurrency harness. Do not change environment construction or global test helpers to hide preparation errors. Current retained observations are in `evidence/2026-10-03-auth-boundary-foundation-7P4K.md`.

The unrelated dirty TypeScript tests, group membership test and exploratory CloudFront memo predate this continuation and must remain intact. No commit, deployment, real browser or live provider verification is implied by local integration tests.

Cancellation now targets the stored transaction rather than the latest pending row. It serializes with Base completion through token/session/transaction locks, closes admitted Auth continuity, and preserves finalized success. Auth returns through Jump to a fixed Base dashboard. Base cancellation uses its stored browser transaction reference. Independent-connection cancellation races and all three complete browser journeys remain unverified.
