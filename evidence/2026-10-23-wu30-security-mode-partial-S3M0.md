# WU-30: Security Mode migration — partial (D-88, D-92, D-132, D-168)

Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72` with the uncommitted cycle changes. From 19:14 the
worktree also holds another session's uncommitted migrations (`2026102319*` in `db/op_base_*_migrate`).
One of them (`20261023194743_bind_sign_up_flows_to_admissions_op_base_com`) fails strong_migrations,
so `db:test:prepare` aborts and **no test ran after the last WU-30 changes**.

## Done

- Migrations `202610231400{00..03}` on app/com/org zenith:
  - create `*_security_modes` with rows 3 and 7;
  - backfill APP/COM to NORMAL and ORG to ADVANCED (D-92);
  - drop `mfa_level_id`, `mfa_level_enabled` and `*_mfa_levels`;
  - set `security_mode_id` NOT NULL with an FK.
  - Applied to development and test databases. Structure dumps edited by hand; FK names were taken
    from the development database.
- `SecurityModeConfigurable` replaces `MfaLevelConfigurable`.
- Sign-in:
  - An invalid mode refuses sign-in (A3/A5).
  - `mfa_required_for?` means ADVANCED, and the ADVANCED second step must be a Passkey (C1).
  - The TOTP MFA endpoint refuses every request, and the APP MFA hub offers only Passkey.
- Passkeys and modes:
  - An ADVANCED Passkey deletion below two is refused under the owner lock (§2.2).
  - APP owner mode update: ADVANCED needs two active Passkeys; leaving ADVANCED revokes every
    session (§2.5).
  - `OrgSecondPasskeyGate` (D-132) limits an ORG Operator with fewer than two active Passkeys to
    Passkey registration and sign-out.
- Sign-up creation sites set the mode explicitly.
- Tests:
  - About 2,000 test creations, the fixtures and the fixture Operators' Passkeys were updated.
  - New `test/models/security_mode_test.rb` (25 runs passed) and the TOTP refusal test (passed).
- Mermaid axis `idp-*-security-mode` was added.

## Last measured state

The full suite before the final fixes had 278 failures and 600 errors. The failing subset after
the fixes had 71 failures and 13 errors, about 60 of them not in G-1. Those include:
- ORG operators that tests create without two Passkeys;
- direct `log_in` tests that now get `mfa_required`;
- tests that expected the old ORG / Emergency behavior.

Several of these were fixed afterwards, but the fixes were not re-run.

## Completed 2026-10-24 (same worktree, HEAD `ba570a0007b1d40eabe32990a34831317fd98a93`)

The suite repair and the Step-Up window and method sets are recorded in
`evidence/2026-10-24-wu24-wu30-suite-repair-and-step-up-windows-R9W3.md`. Also done:
- **COM owner mode update:** `Base::Com::Identity::Mfa::ChallengesController` at
  `/identity/mfa/challenge` (show, update), mirroring APP. New
  `test/controllers/base/com/identity/mfa/challenges_controller_test.rb`, 5 runs passed.
  It covers:
  - a Step-Up redirect;
  - no switch offered with one Passkey;
  - ADVANCED refused with one Passkey and accepted with two, keeping the session;
  - a downgrade revoking the current session;
  - unsupported values 0, 5 and "x".
- **Mode switch UI:** the APP and COM pages render one switch: back to NORMAL, or up to ADVANCED
  with two active Passkeys. Otherwise they show why no switch is offered. Vitest page cases were
  updated; `bun run test` gave 1149 passed; `typecheck`, `lint` and `format:check` are clean.
- **APP social sign-in Passkey requirement:** verified by the existing passing tests
  `OmniauthCallbacksTest` "social login with MFA enabled enters the ordinary MFA challenge" and
  "apple social login with MFA enabled …". Social `auth_method` is never in the MFA bypass, and the
  hub offers only Passkey.
- **Dead TOTP MFA route:** removed, with its controller, page and tests.

## Not done

- ADR 2.5's "one-time" consumption of the downgrade Step-Up is not enforced separately; the
  `settings_mfa` evidence follows the 5 minute ADVANCED window like every other scope.
- The us/ja locale has no `sign.app.settings.mfa` block at all, so the new switch labels are missing
  there, as the existing labels already were.
