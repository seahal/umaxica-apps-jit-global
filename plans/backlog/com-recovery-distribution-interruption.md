# COM recovery distribution after signup interruption

Status: deferred by the owner on 2026-10-07; outside the current `two.md` Goal.

Preserve COM's existing ten-item recovery distribution. Do not adopt app's two-item
Secret issuance policy or change the reveal transport in the current Goal.

The retained [HTTP fault evidence](../../evidence/2026-10-07-com-signup-distribution-recovery-D4Q8.md)
shows that recovery credentials and the original reveal survive a Ticket write
failure, but the signup retry loses the distribution destination. The original
signed token is request-local; the reveal stores its JTI digest, not a recoverable
operation-bound token. This is a distribution recovery problem, not duplicate
credential generation.

A future task must characterize the original distribution, distinguish its
failure from any signup-retry regression, and design authorized recovery of the
original outcome without issuing replacement material, extending deadlines or
guessing another operation's receipt. Review the current GET reveal consumption
separately; no transport or persistence proposal is approved by this deferral.

Retain the failing reproduction and its evidence. No test deletion, skip or
relaxation is authorized. Final verification must identify a failure in this
deferred contract explicitly rather than claiming a fully passing suite.

The [2026-10-08 ceremony-migration reproduction](../../evidence/2026-10-08-email-signup-http-and-deferred-recovery-2R6C.md)
retains the same COM failure: original credentials/reveal survive, but the retry loses its recovery
distribution destination (24 cases, one failure, seed 51931). Its assertions remain enabled.
