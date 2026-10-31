# Local Telephone OTP cooldown column inventory

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes. Schema/count queries were read-only Rails runner queries; Rails boot can execute existing initializers.
- `client_telephones.otp_last_sent_at` and `operator_telephones.otp_last_sent_at` were nullable with no database default in the local test and development databases. Each of the four inspected tables contained zero rows at measurement. The servers reported `10.89.0.3/32` and database names were `test_app_zenith_db`, `test_org_zenith_db`, `development_app_zenith_db`, and `development_org_zenith_db`. No production/Neon database was queried.
- Signup and credential-registration issuers read the Telephone cooldown field; `TelephoneOtpPolicy#otp_window_anchor` also exposes it. The signup issuer handles `-Infinity`, but the credential-registration issuer directly compares a truthy stored value to a time. A local Rails runner confirmed `-Float::INFINITY > Time.current - SEND_COOLDOWN` raises `ArgumentError`.
- These are point-in-time local counts and a comparison probe. No migration, data conversion, test, or code change was performed for this inventory. A complete reader/writer, historical-data and rollback review remains necessary before approving a shape change.
