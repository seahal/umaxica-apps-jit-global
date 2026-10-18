# RP callback and ClientToken multiplicity investigation

## Context

I was investigating why an email sign-up flow failed with a concurrent session limit error even
though the user had just signed up.

## Observed

- A successful sign-up does not stop at creating the `Client` record.
- The flow also issues login/session tokens.
- `AuthenticationBase#create_login_token_record` creates a new `ClientToken` directly.
- The OIDC RP callback path also goes through `OidcTokenExchangeService#consume_and_issue_tokens!`,
  which calls `create_token_record!` and creates another `ClientToken`.
- In the current logs, three distinct `ClientToken` rows were created for the same client during one
  sign-up/login sequence.
- The repeated token creation appears to happen on RP callback retries as well as on the sign-up
  completion path.

## Why It Matters

The current behavior suggests that `ClientToken` is not a singleton per `Client`. Instead, it is a
per-login/session record that can accumulate across the sign-up and callback flow. That is
consistent with the current session-limit code, but it may be surprising if the intended model was
"one RP session per sign-up".

## Open Questions

- Is the intended contract that each successful RP callback must mint a fresh `ClientToken`, even
  during sign-up?
- Should the RP callback reuse an existing token when the same sign-up flow is being resumed?
- Are callback retries expected to be idempotent with respect to `ClientToken` creation?
- Is the current concurrency limit failing because the user already has legitimate active tokens, or
  because the flow is minting duplicates on retry?

## Promotion Candidate

If this behavior is confirmed intentional, document the RP/session-token contract in `docs/` or an
ADR. If it is accidental, the next step is to trace the token minting path and decide where token
reuse or deduplication should happen.
