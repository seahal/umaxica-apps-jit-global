# Signup state inventory reconciliation

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`, with inherited and task uncommitted changes affecting results.
- Compared app/com signup diagrams and their full inventory sections against SignUpStateMachine, FlowSignUp, FlowBase, ClientSignUpFlow, VisitorSignUpFlow, SignUpTermination and SignUpExpiryJob.
- Removed obsolete runtime FINALIZED/HANDOFF_PENDING evidence edges while preserving explicit historical tombstone classifications. Current finalization goes CHECKPOINT_PENDING to FINALIZING to COMPLETED; halt writes HALTED and expired nonterminal decisions persist EXPIRED using the Ticket DB clock.
- Named model cancellation from FINALIZING is documented as model-only; the StateMachine cancel gate still refuses FINALIZING. Social model-map helper labels use the actual named operations rather than the removed transition_to! API. No code transition or status reference was changed for this reconciliation.
- GREEN: `bin/rails test test/services/sign_up/state_machine_test.rb test/services/sign_up_expiry_race_test.rb test/services/sign_up_termination_idempotence_test.rb test/integration/contact_email_signup_source_audit_test.rb test/jobs/sign_up_expiry_job_test.rb`: 34 runs / 241 assertions, zero failures/errors/skips (seed 31118), existing disposable TEST manifest and one Rails worker.
- Scoped diff whitespace check passed. Mermaid renderer and global inventory counts were not verified. This is not a Final Verification or full Phase 25 completion claim.
