# Active contact registration finalization ordering

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting this check.
- Source search found that the current Base APP/ORG Email and Telephone registration controllers call the `*RegistrationOtpFinalizer` operations. A search of `app`, `lib`, and `config` found no caller of the separately named `IdentityEmailCeremonyFinalCommitter` or `IdentityTelephoneCeremonyFinalCommitter` beyond their declarations; dynamic or external callers were not established.
- The APP Telephone OTP finalizer holds an OP transaction around a separately locked principal transaction, mutates the contact and its Source audit inside that principal lock, then consumes the registration result in OP. Step-Up consumption is also inside the still-open OP transaction. This observed order differs from `two.md` XDB-09's specified Ticket-consumption-before-Source order.
- In the existing transactional test, injection of a failure at `consume_registration_result!` left the Telephone binding and Source audit present while the result remained unconsumed. The test now also checks that the Step-Up timestamp remained unchanged. The focused case passed: 1 run, 12 assertions, 0 failures, 0 errors. This fixture-backed injection does not itself prove an independently committed production failure or external exploit.
- The APP Email OTP finalizer has the same outer-OP/inner-Source structure in source inspection; its corresponding failure was not injected in this check. ORG finalizer ordering, independent connections, outer transaction behavior and a complete migration/recovery path remain unverified.
- RuboCop passed for the changed test. No production behavior or persisted shape was changed. The proposed change to the semantics of the consumed registration result was presented for owner review under `generic/data-shape-design.mdc`.

## APP and ORG follow-up

- The APP Email and Telephone SQL-boundary fault cases now additionally check that the original Step-Up timestamp remains after the injected Ticket receipt failure. Each case also observes the new Source binding and audit and the previous binding's release.
- The ORG Telephone receipt-failure case now checks the retained Step-Up timestamp. A new ORG Email case injects the same receipt failure and observes a verified Source email, unconsumed Ticket and retained Step-Up timestamp.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/contact_registration_otp_finalizer_test.rb test/controllers/base/org/identity/emails/registrations_controller_test.rb test/controllers/base/org/identity/telephones/registrations_controller_test.rb -n '/(app_(email|telephone)_finalization_receipt_fault|ORG_Email_Ticket_failure|ORG_named_Telephone_finalizer_ticket_fault)/'`: 4 runs, 85 assertions, 0 failures, 0 errors. RuboCop passed for the three edited test files; scoped `git diff --check` passed before a later blank-line-only edit.
- These fixture-backed injections supersede the earlier statements that APP Email and ORG had not been exercised. They do not prove independent commits, real outages, the ORG audit contract, or a repair. The consumed-result design and failure recovery remain awaiting review.

## Independent APP Telephone commit probe

- A temporary test with transactional fixtures disabled created its own APP actor, session, Telephone candidate and Passkey, then injected a Ticket receipt failure through the public finalizer. After the OP rollback, a separate principal connection observed both the finalized Telephone and its Source audit; the Ticket remained unconsumed and the original Step-Up timestamp remained. The probe passed (1 run, 6 assertions) and removed its own created rows and temporary files.
- This supersedes the limitation that APP Telephone source persistence had only been observed inside transactional fixtures. It does not establish a reachable HTTP exploit, a real outage, independent commit behavior in the other three paths, or a repair.

## Independent APP Email commit probe

- A separate temporary test with transactional fixtures disabled created its own APP actor, session, Email candidate and Passkey, verified an OTP, and injected failure at the Ticket receipt through the public finalizer. A separate principal connection then observed the finalized Email binding and Source audit, while the Ticket was unconsumed and the original Step-Up timestamp remained (1 run, 6 assertions, 0 failures, 0 errors). The probe removed its own rows and temporary files.
- This establishes the independently committed Source outcome for APP Email in the injected scenario, not a real outage, an HTTP exploit, ORG independent commits or a repair.

## Independent ORG contact commit probes

- Separate temporary Email and Telephone tests with transactional fixtures disabled each created an ORG actor, session, candidate and Passkey, verified the OTP, and injected failure at the Ticket receipt through the public finalizer. In each test a separate principal connection observed the contact's `VERIFIED` status after the OP rollback; the Ticket remained unconsumed and the original Step-Up timestamp remained. Each probe passed (1 run, 6 assertions, 0 failures, 0 errors) and removed its own rows and temporary files.
- These ORG probes did not assert an authoritative Source audit, establish a reachable HTTP exploit, exercise a real outage, or repair the ordering. They supersede the earlier statement that independent ORG commits were unverified for the injected receipt-failure case.

## Step-Up resolver follow-up

- The four fixture-backed receipt-failure cases now also call the public `StepUpResolver` with the original registration requirement immediately after the failure. All four report that the original Step-Up requirement remains satisfied. This strengthens the prior timestamp-only observation; it does not show that another protected HTTP action can be completed.
- The APP Email/Telephone SQL-injection cases and ORG Email/Telephone receipt-failure cases passed together: 4 runs, 93 assertions, 0 failures, 0 errors. RuboCop passed for the three edited files after a line wrap.
