# Local Email Step-Up receipt constraint preflight

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes.
- A guarded Rails runner checked the configured host `primary` and database `development_op_base_app_db`, then read `current_database()` and `inet_server_addr()`. The server reported `development_op_base_app_db` at `10.89.0.3/32`.
- Grouping `client_step_up_sessions` by delivery state returned no rows; grouping consumed sessions by delivery state also returned no rows. Counts are a point-in-time observation of local development only. No migration or data update was issued by the query; Rails boot can run existing initializer writes.
- The first boot without the COM Preference JWT issuer configuration failed before the query. Repeating with the existing devcontainer issuer/audience/revocation settings reached the guarded query.
- Production and Neon were not inspected. Counts do not approve the proposed state-shape change or establish recovery for future consumed pending/failed rows.
