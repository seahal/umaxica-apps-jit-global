# Local APP signup OTP binding inventory

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the inspected models and issuers. The inventory used read-only aggregate and projection queries through Rails runners; Rails boot can perform existing initializer work.
- The configured test and development APP OP databases were `test_op_base_app_db` and `development_op_base_app_db`, respectively, on `10.89.0.3/32` at measurement. No production or Neon database was queried.
- Grouping signup Email and Telephone transactions by actor reference, session reference and candidate reference found zero duplicate groups in each of those two databases. This includes groups with equal or different destination digests.
- Recomputing the channel-specific session reference from current Flow IDs and nonce digests found, in the test database, three Email signup transactions matched to a Flow and zero unmatched or expiry mismatches; Telephone had zero signup transactions. The development database had zero Email and zero Telephone signup transactions.
- These are local point-in-time observations, not an inventory of deployed data, historical deleted rows, concurrent writers or every cause of a missing Flow. No data was updated or deleted by the inventory queries.
