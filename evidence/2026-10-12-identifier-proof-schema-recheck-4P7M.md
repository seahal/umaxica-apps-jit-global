# Identifier proof schema recheck

- Revision: `a1ec83a7384a424c97671356268ec5c4ad8347d4`
- Environment: run-owned disposable PostgreSQL fleet `20261010p3d2`; Rails test boot with the manifest and all 20 prepared databases.
- Read-only inspection: the six live identifier tables (`client_emails`, `client_telephones`, `visitor_emails`, `visitor_telephones`, `operator_emails`, `operator_telephones`) have no `otp_private_key`, `otp_counter`, `otp_expires_at`, `sign_up_otp_context`, or `credential_registration_otp_context` columns. Each table retains the channel-specific `otp_last_sent_at` column.
- Limitation: historical migrations, ignored-column declarations, localized labels, and historical diagrams still contain old names; this observation does not by itself prove every old reader or documentation reference has been retired.
