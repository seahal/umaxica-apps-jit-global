# Email settings ceremony HTTP integration

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`. The shared worktree has extensive
uncommitted implementation and unrelated changes; results apply to that worktree, not clean HEAD.
Only configured local test databases were used. No production, remote or secret mutation occurred.

- `bin/rails test test/controllers/base/app/identity/emails/registrations_controller_test.rb
  test/controllers/base/com/identity/emails/registrations_controller_test.rb`: initial RED, seed
  35555, 34 runs / 84 assertions / 22 errors. Actual producers still supplied the retired
  `contact_otp_counter` keyword. After independent Email issuance, verification, finalization,
  encrypted Notifier delivery and original-child session binding: GREEN, seed 36812,
  34 runs / 220 assertions / no failures, errors or skips.
- `bin/rails test test/operations/email_credential_registration_otp_bootstrap_delivery_test.rb`:
  added original-parent resend refusal checks produced RED, seed 23492, 12 runs / 48 assertions /
  six failures. Cancelled parents and invalid original scope/return targets still allowed reissue.
  Resend now locks and validates the original Parent/Session/admission with the original browser
  nonce, then rechecks parent/session deadlines after acquiring the child lock.
- Combined command with that bootstrap delivery file,
  `test/operations/email_credential_registration_otp_resend_issuer_test.rb` and both HTTP files:
  GREEN, seed 22977, 48 runs / 318 assertions / no failures, errors or skips. Coverage retains
  Turnstile, policy/Step-Up, wrong/blank codes, candidate cap, destination budget, old-binding
  replacement/audit, bootstrap, cancellation, closest expiry boundaries, cooldown, generation
  replacement, fixed original expiry and preserved failures.
- Scoped RuboCop on both Email registrations controllers, APP Email redeliveries controller,
  `sign_email_registration_flow`, independent Email resend issuer, both HTTP test files and the
  bootstrap delivery test: eight files, no offenses. Formatting corrections did not relax rules.

Existing registration acceptance tests now read encrypted production Notifier payloads rather
than reconstructing Source HOTP. The Source model's named registration transition validates typed
ceremony evidence; the operation does not write verified status directly. Current Email HTTP
callers retain the original child UUID and bootstrap association rather than resolving a latest
permission. The bootstrap reference is included in keyed verifier and receipt material.

This is targeted evidence, not Final Verification. Telephone/ORG route migration, legacy Source
material and shared-policy removal, HTTP receipt-fault coverage, database proof protections,
full Rails/RuboCop/harness/inventory gates and overall Definition of Done remain incomplete.
