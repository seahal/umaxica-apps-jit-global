# First-page Cancel and Sign In/Up Switch on APP, COM and ORG (D05/D06/D09/D14)

Date: 2026-10-19. Commit: `ff58ff28125fafe405dc76809f6498b64d69e627`, dirty worktree (uncommitted
three.md cycle, credentials/DB change, Passkey limit change). User decision recorded in six.md.

## Finding before the change

RP-facing Cancel and D06 Switch were not implemented. The Sign In/Up page rendered Cancel as plain
text (`SignInMethodChoice.tsx`), and Sign In/Up linked to each other with a direct Auth-to-Auth GET.
The parent authorization transaction had no canceled state, and `AuthCeremonySession#cancel!` had no
caller.

## Change (App; schema for APP/COM/ORG)

- Parent transaction: `canceled` status, `canceled_at` and cancellation handoff columns with CHECK
  constraints; `prepare_cancellation_handoff!` and idempotent `cancel!` (pending only, DB clock, row
  lock). `register_authentication!` already refuses a non-pending parent.
- `POST /sign/cancellation` and `POST /sign/switch` on Auth App, available only on the first page:
  admitted for a pending parent, no authentication evidence, no email OTP, no sign-up cycle.
- Base commits Cancel through a same-origin POST bound to the starting browser and redirects the RP
  with `error=access_denied`, the original `state` and `iss`. Switch issues a fresh admission for
  the same parent only when every earlier redeemed admission's ceremony is cancelled; the admission
  records `entry_intent` and admits only that flow.
- Ceremony session uniqueness per parent now covers only non-cancelled sessions.
- Auth-to-Base redirects use the reviewed Jump gateway, not `allow_other_host`.
- Screens: Cancel and Switch are POST forms; an OIDC-bound page no longer shows the direct link.

## Checks

- `test/integration/sign_entry_exit_flow_test.rb` (real Base start, Auth admission, Auth exit, Base
  continuation and commit): 7 runs, 85 assertions, 0 failures. Covers Cancel to the RP without a
  code, Cancel replay convergence, refusal of a later authentication result, refusal after
  authentication evidence, Switch to Sign Up on the same parent, Switch back to Sign In, and Switch
  refused under `prompt=login`.
- Sign page controller tests, public-entrypoint, redirect-target and forbidden-pattern guards, and
  OIDC authority tests: 100 runs, 810 assertions, 0 failures.
- Step-Up cancellation tests after the shared handoff refactor: 187 runs, 0 failures.
- Vitest for the two choice components: 25 tests passed; `tsc --build` clean.
- Six migrations (cancellation, live ceremony uniqueness, entry intent; per surface) rolled back and
  reapplied. Schema dumps regenerated, keeping only intended hunks.
- RuboCop on the 26 changed Ruby files: no offenses.
- Full suite before the Jump/inventory fixes: 15564 runs, 5 failures, 18 errors. Three failures were
  these guards (now fixed); the rest are the 14 worker-receipt Avatar tests and the user-owned
  `inertia_rails` 3.23.0 failures.

## Com and Org

- Com: same Cancel and Switch; Org: Cancel only. The coordinator refuses any Switch on the `org`
  surface (no public Org Sign Up), and the Org page receives no Switch form.
- `test/integration/sign_entry_exit_com_org_flow_test.rb`: Com Cancel to the RP, Com Switch to Sign
  Up on the same parent, Org Cancel to the RP with no Switch form, Org Switch refused. Together with
  the App file: 11 runs, 127 assertions, 0 failures.
- Com/Org sign page tests: 20 runs, 0 failures. Vitest: 294 tests passed; `tsc --build`, oxlint and
  oxfmt clean.

## Final full suite

15568 runs, 132668 assertions, 2 failures, 18 errors. All are pre-existing and unrelated: 14
committed-transaction Avatar tests that need an isolated worker run, and 6 caused by the user-owned
`inertia_rails` 3.23.0 upgrade (`/_inertia/devtools` routes, `clearHistory`), which the user asked
not to touch.
