# Account enumeration review: sign-in and sign-up entry points

Date: 2026-09-19
Follows: `2026-09-19-passkey-allow-credentials-enumeration-P3W6.md` (open items)

## Summary

The two open items of the passkey review were followed up.

1. **Real `webauthn_id` lengths:** not measured. The development database has no passkeys
   (`ClientPasskey`, `VisitorPasskey`, and `OperatorPasskey` each returned `count = 0` through a
   read-only `bin/rails runner` query on the reading role). Production was not accessed. Finding 2
   of the passkey review stays "likely, unverified".
2. **Other identifier-first entry points:** two further account-existence oracles were found and
   reproduced with integration requests. Both come from a server-side cooldown that applies only to
   one class of address, while the cooldown that applies to every address is stored in the client's
   own session and is reset by starting a new session.

| Entry point | Result | Basis |
|---|---|---|
| app email sign-in (`Auth::App::Sign::In::EmailsController#create`) | **Oracle**: registered address returns 429 on the second submission | Reproduced |
| com email sign-in (`Auth::Com::Sign::In::EmailsController#create`) | Oracle expected (same code path, `emails_controller.rb:283`) | Code reading |
| app email sign-up (`Auth::App::Sign::Up::EmailsController#create`) | **Oracle**: unregistered address returns 429 on the second submission | Reproduced |
| com email sign-up, app/com telephone sign-up | Oracle expected (same `reregistration_window_active?` logic) | Code reading |
| app secret sign-in (`Auth::App::Sign::In::SecretsController`) | No oracle found: one error message for every failure reason, `MinimumResponseBudget` | Code reading |
| passkey options (app, com) | Oracle (see the passkey review) | Code reading |
| org surfaces | Not applicable: identifier comes from Entra | Code reading |

## Reproduction method

A temporary integration test was written under `test/controllers/auth/app/in/`, run once with
`bin/rails test`, and deleted. It is not in the repository. For each address it made two `POST`
requests, **each from a fresh integration session** (`open_session`, no shared cookies), with the
Turnstile stub returning success. A fixture `ClientEmail` provided the registered address.

Observed output:

```
Sign-in  POST /sign/in/email
PROBE probe_registered@example.com:   [[302, ""], [429, "しばらくしてから再度お試しください。"]]
PROBE probe_unregistered@example.com: [[302, ""], [302, ""]]

Sign-up  POST /sign/up/email
PROBE probe_registered@example.com:   [[302, "sign/up/check/email/otp"], [302, "sign/up/check/email/otp"]]
PROBE probe_unregistered@example.com: [[302, "sign/up/check/email/otp"], [429, "しばらく時間をおいてから再度お試しください。"]]
```

The existing `test/controllers/auth/app/in/emails_controller_enumeration_test.rb` submits both
requests **in one session**. It therefore exercises only the session cooldown, which is uniform,
and passes while the cross-session oracle exists.

## Finding A: email sign-in

`Auth::App::Sign::In::EmailsController#create`:

- `sign_in_email_cooldown_active?` (line 459) reads `session[:sign_in_email_cooldown_address]` and
  `session[:sign_in_email_cooldown_at]`. It applies to every address, but it lives in the client's
  session cookie, so a new session starts without it.
- `process_email_authentication` returns `:cooldown` only for an existing address, when
  `otp_request_rate_limited?` → `ClientEmail#otp_cooldown_active?` is true
  (`otp_last_sent_at` within `CommonOtpPolicy::SEND_COOLDOWN`, 30 seconds). This state is stored on
  the server, on the email record.
- For an unregistered address, the dummy branch never sets a server-side timestamp.

Result: two submissions within 30 seconds from two sessions return 302 then 429 for a registered
address and 302 then 302 for an unregistered one.

Side effect for the attacker: the first submission sends a real OTP email to the account owner, so
each probe is visible to the victim.

## Finding B: email sign-up

`SignEmailRegistrable#process_email_registration_under_lock` (line 113):

- A registered (non-pending) address takes the `:dummy_existing` branch every time and redirects to
  the OTP check page.
- An unregistered address creates a pending registration on the first submission. A second
  submission within `CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW` (10 seconds) hits
  `reregistration_window_active?` and returns `:cooldown`, which the controller renders as 429.

Result: the oracle is inverted compared with sign-in: the unregistered address is the one that
returns 429. The window is 10 seconds.

Side effect for the attacker: the first submission for an unregistered address sends an OTP to that
address; nothing is sent to a registered address.

## Combined impact

- An attacker can determine whether a specific email address has an account on the app surface,
  and very likely on the com surface. Telephone sign-up is expected to behave the same way.
- Existing controls (per-IP rate limits, Turnstile, and the per-address sign-up limit of 10 per
  10 minutes in production) make bulk enumeration slower. A targeted check needs only two
  requests, well inside every limit.
- The code states non-disclosure as a design goal (dummy OTP work, dummy state, the comment in
  `create`, and the existing enumeration test). These oracles defeat that goal.
- Fixing only the passkey padding would not change the overall exposure, because the email sign-in
  and sign-up paths disclose the same fact.

Severity: Medium for the combined account-enumeration exposure (ASVS 6.3). No path gives access to
an account.

## Remediation direction

The rule to enforce: **any cooldown that can change the response must be keyed only on data that is
the same for registered and unregistered identifiers, and must be stored on the server.**

1. Replace the session-stored per-address cooldown with a server-side one keyed on the normalized
   address digest (for example, in the existing rate-limit store), applied before the account lookup
   and identical for every address. The record-level `otp_cooldown_active?` can then stay as a guard
   against resending, but its result must map to the same response as a successful submission.
2. Sign-up: when `reregistration_window_active?` is true, respond exactly as the `:dummy_existing`
   branch does (redirect to the OTP check page without sending), instead of 429.
3. Passkey options: see the remediation in the passkey review (deterministic dummies, realistic
   lengths, stable ordering).
4. Tests: change the enumeration tests so that each request uses a fresh session, and add the same
   cross-session assertions for sign-up, com, and telephone paths.

## Not covered

- Telephone sign-up and the com surface were not reproduced; their status comes from code reading.
- Response timing was not measured. The email sign-in controller has no `MinimumResponseBudget`,
  unlike the passkey and secret controllers.
- Password reset and recovery-style entry points (enforcement recovery, withdrawal re-entry) use
  the same `otp_cooldown_active?` pattern (`EnforcementRecoveryCeremonyFlow`,
  `WithdrawalCeremonyReentry`) and were not reviewed for this oracle.
