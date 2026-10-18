# P3d Mermaid policy-axis reconciliation

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty and was preserved. No application, schema, migration, database,
production or external-service change was made by this documentation slice.

## Reconciliation

The runtime inventory found no current `app/`, `lib/` or `config/` writer, reader or lifecycle
method for identifier-owned `otp_private_key`, `otp_counter`, `sign_up_otp_context`,
`credential_registration_otp_context`, `store_otp`, `get_otp`, `clear_otp`, `otp_expired?` or
`otp_active?`. The current channel policy sources are `EmailOtpPolicy` and `TelephoneOtpPolicy`;
ceremony-owned proof is represented by the concrete Email/Telephone ceremony transaction and
issuer/verifier paths. Historical migration, ADR, locale, test-negative-assertion and log-filter
references remain intentionally bounded historical or defensive material.

The six realm/channel derived Mermaid files were rewritten to show independent failure/lock
predicates, explicit Telephone issuance time, preserved failures on issuance/expiry/cancellation,
successful-consumption reset and separate ceremony proof ownership. The state-axis and value-
coverage inventories now point at existing policy/transaction/operation files. The transition
inventory explicitly labels its retained Source-HOTP rows as historical traceability, not current
runtime authority.

Checks:

```text
git diff --check
scripts/check-repository-knowledge
```

Observed result: both checks passed. This is documentation consistency evidence only. It does not
close the remaining P3d source/fixture/constraint retirement inventory or prove the full
CONTACT-4/5 purpose, realm and concurrency matrix.
