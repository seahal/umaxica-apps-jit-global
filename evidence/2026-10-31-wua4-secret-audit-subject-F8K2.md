# Secret audit subject attribution probe

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the tested job and model.
- A temporary test created two distinct Clients and a Source Secret audit event with the first as request actor and the second as `client_ref`. After `ClientSecretAuditDeliveryJob.perform_now`, the Chronicle actor and subject IDs both equaled the actor, not the owner; metadata retained the owner's public reference. The test passed with 1 run and 4 assertions and was removed afterward.
- This verifies the delivery attribution for the constructed, model-supported event. It does not establish a public cross-owner Secret workflow, deployed records, autonomous-event delivery, or an approved repair/backfill contract.
