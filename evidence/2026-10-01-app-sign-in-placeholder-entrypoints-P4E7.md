# App sign-in placeholder entrypoints

Commit: `91974b8b05ccda80afcb1beb3174ab48f4155889`.
The worktree contained unrelated uncommitted changes, including locale changes; this verification
also includes the uncommitted placeholder routes, controllers, chooser changes, tests, and docs.

App alone reserves `GET /sign/in/emergency` and `GET /sign/in/device`. Both controllers inherit
directly from `Auth::App::ApplicationController`, declare guest mode, and render translated plain
mock responses with no Emergency operation or cross-device protocol wiring. Sign-in orders Email,
Passkey, Emergency, Device, Google, Apple, separator, registration, and text-only Cancel. The shared
chooser shows the separator and Cancel only with the app-supplied optional label. App sign-up also
appends text-only Cancel using `actions.cancel`.

## Results

- The new frontend assertions first failed for absent separator/Cancel; the sign-up assertion first
  failed because the last item was still the sign-in link.
- Initial sandboxed Rails tests could not connect to host `primary`; no assertions ran. The existing
  test databases were reachable outside the sandbox.
- Related Rails command below: **62 tests, 925 assertions, zero failures/errors/skips**.
- Full `bin/rails test` outside the sandbox: **12,137 tests, 79,483 assertions, zero failures/errors,
  two existing skips**, completed in 270.995 seconds. No test was deleted or newly skipped by this change.
- `bun run test`: **87 files, 1,063 tests passed**, including both updated chooser specs.
- `RAILS_ENV=test bin/rails zeitwerk:check`: **All is good!**
- `RAILS_ENV=test bin/rails routes -g 'sign_in_(emergency|device)'`: app GET helpers target
  `auth/app/sign/in/emergencies#show` and `auth/app/sign/in/devices#show`. Existing org emergency
  passkey routes remain separate. Related route tests verify mutation and com/org absence, and
  absence of both legacy URLs.
- RuboCop on the twelve changed Ruby implementation/test files: **no offenses** after correction.
- Oxfmt on the four changed TSX files and `git diff --check`: **passed**.
- `bun run typecheck`: **failed** at two untouched files:
  `spec/features/dashboards/base_dashboard_identity.test.tsx:43` (optional `heading`) and
  `src/pages/base/org/avatars/show.tsx:25` (`description` can be undefined). No errors remained in
  the changed files.
- Live browser rendering was not checked; no browser/Chrome DevTools tool is available.

Related Rails command:

```sh
bin/rails test test/controllers/auth/app/sign/in/emergencies_controller_test.rb test/controllers/auth/app/sign/in/devices_controller_test.rb test/controllers/auth/app/sign_ins_controller_test.rb test/controllers/auth/app/sign_ups_controller_test.rb test/controllers/auth/com/sign_ins_controller_test.rb test/integration/routes/auth_sign_ceremony_route_contract_test.rb test/controllers/auth/route_naming_test.rb test/controllers/auth/app/sign_in_boundary_test.rb test/controllers/controller_inheritance_invariant_test.rb
```

The Emergency acknowledgement ADR, canonical plan, decision proposal, and remaining-work ledger
now name `/sign/in/emergency` as the public entrypoint while keeping credential issuance/sign-in
behavior open. The commit-acknowledgement security decision is unchanged.
