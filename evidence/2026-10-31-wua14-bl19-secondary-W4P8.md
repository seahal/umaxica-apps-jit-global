# BL-19 secondary candidate checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- `PARALLEL_WORKERS=1 bin/rails test test/lib/outbound_http/connection_adapter_port_test.rb test/models/string_column_length_validation_contract_test.rb test/jobs/client_secret_audit_delivery_job_test.rb` passed: 198 runs, 1792 assertions, 0 failures, 0 errors, 0 skips.
- The tested IPv6/port, string-length and Client Secret audit-delivery cases did not reproduce the historical triage failures in this run. This does not establish untested network destinations, all audit failure windows, or every BL-19 candidate.
