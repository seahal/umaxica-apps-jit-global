# ORG Support mutation through opaque step-up

Commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes and unrelated parallel work.

Migrated the Support session-revocation success case in `test/integration/org_admin_step_up_ceremony_test.rb` from signed ceremony grants/results and injected Auth authentication to current Base confirmation POST, opaque admission, Auth CSRF continuation, options POST, real WebAuthn assertion, opaque result form, Base completion and the final protected mutation. Base and Auth use separate integration sessions/cookie jars. Auth receives no root token. The recorded credential reference, consumed ticket, original verification timestamp, scope/session/audience and successful administrative audit are asserted.

The test then revokes the operator's Support mutation capability through its public API. A subsequent JSON mutation returns 403, preserves the target session, creates no successful revocation audit and leaves the previously established freshness timestamp unchanged. Freshness therefore does not replace the final business authorization. HTML authorization denial retains its existing redirect behavior; no response contract changed.

Command: `bin/rails test test/integration/org_admin_step_up_ceremony_test.rb -i /support_revocation_passes_opaque/`, with owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, one worker and preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`.

Result: one selected test, 33 assertions, no failures/errors/skips (seed 50816). RuboCop on the changed integration file passed after formatting; `git diff --check` passed.

Limitations: the initial Base token is a fixture authenticated through the existing Base token API, not a completed ORG root-login journey. WebAuthn uses the gem's fake authenticator with actual signature verification; Turnstile is stubbed. The test extracts the Auth destination from the Jump transport rather than exercising Jump in a browser. The five remaining cases in this file still use legacy contracts and were not run in this selected check. No browser verification, schema changes, OTP logging remediation or deployment occurred.
