# Final adversarial security scan

- Date: 2026-09-22
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing local modifications and untracked evidence files were present; no
  source, test, configuration, database, or external-service changes were made during this
  scan.

## Scope

The final review followed the implemented paths rather than relying on comments or prior reports.
It checked:

- app/com direct Passkey options for actor binding and credential disclosure;
- Org, MFA, and Emergency Passkey paths for intentional actor-bound descriptor retention;
- TOTP `REVOKED` terminal behavior and the bounded failure counter;
- first-party browser RP neutral intent and absence of normal `screen_hint` emission;
- reviewed diagnostic logging for direct raw credential, OTP, PKCE, admission, or refresh-token
  values.

## Results

The app/com direct Passkey options paths issue an actor-unbound challenge and return an empty
`allowCredentials` list. The actor-bound descriptor path remains only for Org/MFA/Emergency
ceremonies, where it is part of the existing contract. Tests also assert that app/com options do
not disclose stored credential IDs.

The TOTP model and consumer tests cover the terminal `REVOKED` state, the 100-attempt ceiling,
and concurrent/competing verification behavior. No reactivation path was found in the reviewed
TOTP lifecycle.

The Base first-party browser RP path maps ordinary authentication to the neutral intent even when
an incoming `screen_hint` is present. Remaining `screen_hint` references are in non-first-party
or special-purpose test/flow inputs and do not change this first-party contract.

The reviewed logging scan did not identify a new direct logging expression for raw OTP, PKCE
verifier, admission code, access token, or refresh token values. Some generic exception messages
remain diagnostic inputs; this scan does not claim that every exception class can never include
attacker-controlled text, so the broader observability redaction boundary remains a separate
defense and regression area.

## Verification

Command:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_zenith_db
PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/in/passkeys_controller_test.rb test/controllers/auth/com/in/passkeys_controller_test.rb test/controllers/auth/org/in/passkeys_controller_test.rb test/controllers/auth/org/in/emergency/passkeys_controller_test.rb test/controllers/concerns/passkey_sign_in_flow_refusals_test.rb test/unit/security/passkey_options_anonymity_invariant_test.rb test/consumers/totp_window_consumer_test.rb test/consumers/totp_window_consumer_concurrency_test.rb test/models/client_totp_credential_test.rb test/models/client_totp_credential_enrollment_concurrency_test.rb test/integration/routes/neutral_rp_entry_contract_test.rb test/controllers/base/oauth_oidc_authority_test.rb
```

Result: `149 runs, 813 assertions, 0 failures, 0 errors, 0 skips`.

`git diff --check` also passed. No external service was contacted or changed.

## Disposition

No new blocker was opened by this scan. Existing external or contract-gated items remain open
where the repository cannot prove them locally; in particular, this scan does not close regional
RP deployment, production worker topology, provider notification delivery, or unresolved owner
mapping decisions.
