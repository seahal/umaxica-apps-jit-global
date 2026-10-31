# APP signup resend at the OTP deadline

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- Before the change, the Email and Telephone issuer files passed (21 runs, 280 assertions). A new operation boundary test showed both issuers reissued an expired OTP at and one microsecond after its deadline (6 runs, 24 assertions, 4 failures).
- For an existing transaction, the issuers now lock it, recheck the binding, and require its current generation to be deliverable at the Ticket database clock before issuing a replacement. Both channels issue one microsecond before expiry and return the existing `closed_challenge` result at and one microsecond after expiry without changing the old proof or Source cooldown (6 runs, 36 assertions).
- The broader signup issuer, guard, concurrency, transport and controller files passed before a semantics-preserving helper extraction (202 runs, 1,985 assertions). After extraction and formatting, the deadline, both issuer and independent-lock files passed again (31 runs, 332 assertions). Scoped RuboCop and tracked-file `git diff --check` passed.
- The status/state diagrams and transition inventory were updated. This test exercises the public operations with controlled clocks, not an HTTP expiry response, an actual delivery, or the full XDB-14 matrix. A live explicit resend may still set a fresh OTP deadline within the unchanged Flow deadline; whether the specification requires the previous OTP deadline itself to be retained remains a separate open interpretation.
