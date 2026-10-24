# WU-08: Social callback state matrix (D-48 with D-72)

Commit: `ba570a0007b1d40eabe32990a34831317fd98a93`, with this cycle's uncommitted changes in the
worktree.

## Implemented in `SocialAuthLoginHandler`

| Case | Behavior                                                                                                                                                                                       |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| L8   | An in-force `AppEnforcementIdentifierEffect` on the Google/Apple subject digest is checked first, before any identity lookup. Both intents are refused with `errors.social_auth.unauthorized`. |
| L5   | A subject released during the ceremony is refused (`identity_conflict`), as before.                                                                                                            |
| L1   | An unknown subject is refused on sign-in, and becomes a pending sign-up on sign-up, as before.                                                                                                 |
| L7   | The lookup now sees every identity state. `consent_revoked` and `account_deleted` are refused in both intents.                                                                                 |
| L4   | An identity without its Client raises `SocialAuth::IdentityInvariantError` (HTTP 500) after a FATAL `social_auth.identity_without_client` event. The "treat as unknown" branch is gone.        |
| L6   | A subject linked to a Client still `UNVERIFIED_WITH_SIGN_UP` is refused in both intents (`pending_social_signup_invalid_state`).                                                               |
| L2   | A registered subject signs in on sign-in and is refused on sign-up (`identity_conflict`).                                                                                                      |
| L3   | A linked Client that cannot sign in is passed to Sign In, whose eligibility check refuses it with its existing status (the 403 path is unchanged).                                             |

The linked Client is read explicitly (`association(:client).scope.take`) because the identity is
strict-loading.

## Tests

- `test/services/social_auth_login_handler_test.rb` was rewritten as the matrix (8 runs, 0 F):
  - L1 in both intents;
  - L2 in both;
  - L3 handed to Sign In;
  - L4 raising, with the FATAL event (the repository is replaced, because the row cannot be stored);
  - L6 in both intents;
  - L7 for both states in both intents;
  - L8 in both intents, decided before identity state and even with no identity;
  - the race conflict.
- `SocialLoginAdmissionTest`: "an existing Google subject started at signup …" now asserts the L2
  refusal: redirect to `/sign/in`, no ceremony evidence, transaction still pending, no token.
- **Not changed:** the G-1-red `SocialAuthLoginTest` "… sign up entry with existing identity falls
  through to sign in flow" cases. They still expect the old fall-through, which L2 now refuses, and
  stay red.
- **Not covered:** Apple-specific L7/L8 cases (only Google subjects are exercised), and the "no Flow
  or pending Client created on any refusal" assertion for each case at HTTP level.

## Runs

- Social integration set (10 files and directories): 90 runs, 18 F, 0 E; all in G-1.
- Handler and admission tests: as above.
- `rubocop` on the changed files: no offenses.

## Current Visa/RP verification

The current social admission and callback journey uses a separate Visa browser context for the OP
authorization and result resources. The focused social batch, including auto-linking, entry/start
contracts and sign-up checkpoint cancellation, passed **33 runs, 235 assertions, 0 failures and 0
errors**.
