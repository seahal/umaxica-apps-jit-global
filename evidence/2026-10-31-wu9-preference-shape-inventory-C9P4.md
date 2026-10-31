# APP/ORG Preference local shape inventory

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes affecting the inspection.
- Queried the configured local development APP/ORG setting and Zenith writer databases after verifying their `development_*` names and local `10.89.0.3` address. At the time of inspection the APP, ORG, Client and Operator Preference parent tables each contained zero rows.
- Both anonymous parent tables have non-null `binding_method_id`, `dbsc_status_id` and `explicit_fields`, plus nullable `jti`; the zero-row tables have zero null `jti` values. Client and Operator parent tables have non-null `user_id` and `staff_id` respectively, and nullable `consented_at`, `consent_version` and `explicit_fields`; zero rows means zero nulls at this instant.
- The inspection does not measure child tables, future writes, other environments, actual consent semantics or every column in Appendix S. Rails development boot can run its existing Preference reference initializer. No migration, reset, production or Neon operation was performed. Counts must be refreshed before any approved destructive operation.
