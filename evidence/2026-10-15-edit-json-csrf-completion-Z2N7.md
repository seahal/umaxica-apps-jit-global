# Edit JSON completion CSRF error response

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
implementation/test/documentation changes.

Extended the twelve-client completion matrix with JSON requests carrying a valid intent proof but
invalid form/header Rails authenticity tokens. The first run reproduced Edit ORG returning 422
instead of the existing JSON CSRF contract's 403 (1 run / 370 assertions / 1 failure). Edit sign-out
intentionally inherits BareController and lacked the shared CSRF response handler. Added
SignErrorResponses and its existing InvalidCrossOriginRequest handler only to Edit sign-out,
preserving its bare inheritance and independent Browser RP authority boundary.

The completion matrix plus authority-first integration selection passed 6 runs / 837 assertions / 0
failures / 0 errors / 0 skips. Every registered client returns JSON 403 without advancing its
transaction, then accepts the valid continuation. Targeted RuboCop inspected two files without
offenses and scoped diff checking passed. Only normal Rails test databases were used with the
isolated-run identifier unset; no reset or isolated fleet. External/manual and remaining full
authority-flow acceptance are separate unfinished work.
