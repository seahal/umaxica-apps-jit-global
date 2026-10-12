# P3d physical proof-schema retirement inventory

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- Worktree: 213 changed paths were preserved; no database reset, shared-resource mutation, commit or push was performed.
- Scope: disposable PostgreSQL fleet `20261010p8b`; catalog queries used Rails model-owned writing connections and emitted only names/count-style facts.

## Catalog checks

For `client_emails`, `client_telephones`, `visitor_emails`, `visitor_telephones`, `operator_emails` and `operator_telephones`:

- physical columns `otp_private_key`, `otp_counter`, `otp_expires_at`, `sign_up_otp_context` and `credential_registration_otp_context`: zero remaining columns in all six tables;
- corresponding retirement migration versions are present in the owning databases: APP `20261010230339` and `20261010232748`, COM `20261010230343` and `20261010232752`, ORG `20261010230350`;
- constraints, non-internal triggers and public functions whose definitions reference any retired column: zero in APP, COM and ORG Zenith databases.

The physical catalog portion of CONTACT-5 is therefore current for this disposable rehearsal. Historical migration definitions, intentional forbidden-key/redaction lists, stale test names and adapter rejection fixtures remain traceability evidence rather than runtime writers. This check does not authorize real-data destructive migration, prove every delivery consumer, or close the full P3d route/purpose/realm/concurrency matrix.
