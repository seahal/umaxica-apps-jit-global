# Browser admission and normal Secret login

Observed on 2026-10-05 UTC against
`e8f2371bc5cbefd2087c728aeeef4e318463d33f`, with uncommitted Secret and
unrelated concurrent changes. No production write, push, or deployment was performed.

A task-owned Rails browser server was started on loopback port 3193 using the
guarded `/tmp/umaxica-secret-db-task.rb` runner and existing disposable
`20261003secret` database fleet. Its process-local Turnstile substitute explicitly
accepts synthetic third-party challenges. Issuance, purge, outbox and proof
retention proposals were explicitly set to 600, 86400, 604800 and 2592000 seconds.
Existing servers on other ports were preserved.

The new `e2e/app-secret-sign-in-entry.spec.ts` attempts server-issued Base browser
admission, the Auth admission form, six distinct authentication controls and the
Secret form for `ri=us` and `ri=jp`. It substitutes the external Jump adapter and
verifies redirect-ticket ES384 signature, fixed issuer, audience and destination
before using the target. The browser transport preserves public app origins,
Host and forwarded HTTPS while targeting the loopback disposable server.

Command:
`PLAYWRIGHT_NO_COPY_PROMPT=1 E2E_ISOLATED_RAILS_RUNNER=/tmp/umaxica-secret-db-task.rb E2E_BASE_SERVICE_URL=http://base.app.localhost:3193 E2E_AUTH_SERVICE_URL=http://auth.app.localhost:3193 E2E_JUMP_SERVICE_URL=https://jump.umaxica.net bun run test:e2e e2e/app-secret-sign-in-entry.spec.ts`

The initial two cases did not pass. Initial attempts exposed a local DNS transport
failure, then a third-party speculation-resource request being mistaken for a
Jump navigation. Loopback transport and distinct resource routing were corrected.
That execution still timed out at the Jump-to-Auth navigation, before method
selection or Secret input. Browser redirect interception requires further work.
This does not establish successful browser Secret sign-in.

The URL assertion in that failed execution printed short-lived signed redirect
tickets. No Secret value or authentication cookie was submitted by these cases.
The assertion now reports only hostname/path and does not print query
values. Raw diagnostics are not copied into this evidence record. Future transport
failures use credential-free errors; trace, screenshot and video remain disabled.

`bun x oxlint e2e/app-secret-sign-in-entry.spec.ts` passed after route handlers and
DOM-based method assertions replaced conditional dispatch and unsafe parsed-prop
assertions. Subsequent execution and its limits are recorded below.

## Verified HTTPS browser journeys

The installed Playwright declaration at
`node_modules/playwright-core/types/types.d.ts:4413` documents that route handlers
only receive the first URL of a redirect chain. A task-owned HTTPS proxy was
therefore started on loopback port 3443 with a one-day self-signed test certificate.
Chromium host-resolution rules map the explicit Base, Auth, Jump and Turnstile
hosts to this listener and resolve other hosts to failure. Browser redirects,
native POSTs and secure cookies retain their public HTTPS origins. App requests
are forwarded to loopback Rails 3193 with Host and forwarded HTTPS preserved.
Jump and Turnstile are external adapter substitutes; Jump input is signature,
issuer, audience and fixed-target verified before its real 303 response. No
application authorization or session issuance response is fabricated.

The Auth admission and result documents automatically submit their own
CSRF-protected forms. Removing the test's nonexistent manual submit interaction
allowed both region cases to pass: 2 Chromium tests, 8.0 seconds. Each checks
email, Passkey, Device, Google, Apple and Secret as distinct rendered controls,
the Secret URL and region, then visits the real Secret form.

The additional `--grep browser-saved` case creates a declared existing management
session/Step-Up fixture, then uses actual browser manual issuance, protected
presentation and storage confirmation. It revokes that fixture session, clears
cookies and starts server-issued guest admission. Secret authentication evidence
passes through Auth's native handoff/result documents to canonical Base login.
The database check finds exactly one normal Secret root token, its matching
receipt, the matching irreversible claim and consumed credential. Another guest
flow receives HTTP 422 for the saved value and creates no second Secret root.

Initial attempts found two challenge fields and a nonexistent manual handoff
button. More significantly, the newly created management fixture's root anchor
caused the real 30-second cooldown to reject Base issuance after claim. No
cooldown setting was disabled. The test now revokes the fixture and waits against
the writer clock and `AuthenticationBase.login_cooldown` before starting guest
admission. The final targeted command passed: 1 Chromium test, 52.2 seconds
(51.8 seconds for the case), on the same HEAD with uncommitted changes.

`bun x oxfmt --write e2e/app-secret-sign-in-entry.spec.ts` and
`bun x oxlint e2e/app-secret-sign-in-entry.spec.ts` passed. Trace, screenshots,
video and ARIA snapshots are disabled; the installed Playwright implementation
at `node_modules/playwright/lib/index.js:658` confirms the snapshot suppression.
Management fixture authorization is explicit setup, not browser Step-Up proof.
Actual browser signup, fresh browser Passkey Step-Up, forced bfcache restoration,
analytics/log capture and the full parallel-submission matrix remain unverified.
