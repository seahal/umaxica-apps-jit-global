# Registration generation supersession

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted worktree changes affect the results.

`bin/rails test test/operations/credential_registration_otp_supersession_test.rb` reproduced stale
transport after repeated new issuance in all three realms and both channels: 12 tests,
78 assertions, six failures, no errors/skips (seed 38475). Independent issuer changes cancel only
the same original actor/candidate/Root/browser challenge, before replacement in Ticket's transaction.

The supersession test, shared registration issuer tests, failure-retention tests and independent
Email/Telephone issuer files then passed 57 tests and 795 assertions (seed 14226). With explicit
transport invocation assertions added, the supersession plus original Email bootstrap delivery and
Email resend tests passed 26 tests and 278 assertions (seed 5310). No failures, errors or skips.
Scoped RuboCop passed both issuers and the supersession test. These are focused results, not final
verification or a distributed-transaction guarantee.

The separate supersession rollback file passed all six realm/channel cases and 48 assertions
(seed 23206). An injected failure at the actual Source timestamp SQL update restores the prior
challenge facts and transport eligibility and leaves no replacement Ticket row. Scoped lint passed.

The existing delayed signup transport matrix was migrated from Source HOTP/counter fixtures to
actual independent issuers/verifiers, typed transactions, UUID generations and encrypted SMS
version-three payloads. All 24 scenarios remain: two Email transports and SMS in APP/COM, each
current/reissued/consumed/expired. It passed 24 tests and 154 assertions (seed 55659). Full Rails,
full RuboCop and final invariant/inventory gates remain unverified.
