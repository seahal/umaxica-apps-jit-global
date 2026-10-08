# ORG Email and actual browser receipt recovery

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`. Extensive uncommitted work affects these
results. All commands used the normal local test runner without additional environment variables;
no production, external-service or remote mutation occurred.

- Independent Email issuance/verification expanded to ORG: initial six-test command failed on
  unsupported realm (seed 35107, two errors), then on incorrectly assuming ORG identifier
  `accessible?`/binding columns (seed 21664, two errors). Explicit ORG ownership/status semantics
  replaced that assumption. GREEN: six runs / 117 assertions, seed 35391, no failures/errors/skips.
- ORG form-query, late-delivery and Notifier additions: RED nine runs / 69 assertions, seed 54577,
  two unsupported-realm errors and one real delivery failure. The ORG Notifier dropped registration
  bindings and its mailer delivered cancelled proof. Typed ORG guard dispatch, generation propagation
  and delivery-time validation fixed it. With the issuer file: GREEN fifteen runs / 204 assertions,
  seed 48463, no failures/errors/skips.
- Positive original-bootstrap resend probes caught the wrong Session status/expiry field names:
  twelve failures in the combined RED seed 24681. The guard now uses `PENDING` and `discard_at`.
  Focused bootstrap delivery/resend: GREEN twelve runs / 144 assertions, seed 18560.
- Three existing Email browser integration files were migrated without removing their eighteen
  journeys: `contact_registration_otp_bootstrap_receipt_recovery_test.rb`,
  `contact_registration_otp_http_resend_test.rb`, and
  `contact_registration_otp_noticed_transport_test.rb`. Receipt fault injection now targets the
  lifecycle status write, not earlier Ticket OTP consumption. Snapshot checks preserve every fact
  except explicit OTP/reissuance effects and assert the exact optimistic-lock increment.
- Combined integration found four real bootstrap retry failures: wrong retained-code guesses
  received 401 before OTP failure accounting instead of 422 (seed 47193). Narrow receipt admission
  now checks original Root/browser/Parent/Session/admission, current policy, committed Source audit
  provenance and bounded pending receipt. It permits only verification of that original receipt;
  the verifier and finalizer still require the correct keyed code. Wrong guesses increment the
  candidate budget without changing proof, issuance timestamp or finalized binding.
- Final command: `bin/rails test
  test/controllers/base/org/identity/emails/registrations_controller_test.rb
  test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb
  test/integration/contact_registration_otp_http_resend_test.rb
  test/integration/contact_registration_otp_noticed_transport_test.rb`.
  GREEN: thirty-one runs / 758 assertions, seed 10630, no failures/errors/skips. This includes
  actual protected bootstrap browser journeys, child/parent receipt persistence faults, wrong-code
  refusal, exact retry without Source/audit rewrite or freshness grant, encrypted late transport,
  cooldown BVA and ORG registration HTTP.

ORG Email now uses ceremony proof and explicit original-child session binding. Its separate
finalizer preserves the existing passkey-only requirement, current credential and Root/device
checks; the named OperatorEmail transition validates typed evidence before writing verified status.
Source commits precede Ticket lifecycle receipt. A locked candidate remains persisted rather than
being purged and losing its failure state. No new production schema change was needed for this
HTTP integration; existing ceremony columns and realm-specific status contracts were used.

Additional ORG finalizer denial tests remain pending: the first expanded run had one fixture error
because a disabled Step-Up requirement cannot carry enabled-only properties. The corrected test
uses a representable broadened method set. Do not count these additional cases as passed yet.
Full Rails/RuboCop/harness/inventory checks, remaining Telephone/ORG migration and legacy material
retirement remain unfinished; this evidence does not certify the overall Definition of Done.
