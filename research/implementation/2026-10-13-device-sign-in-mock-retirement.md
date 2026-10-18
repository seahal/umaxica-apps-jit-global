# Device Sign-in Mock Retirement Implementation Notes

## Context

- Original plan: frozen `one.md`, “Device Sign In mock retirement”; frozen `two.md`, AT-012 and
  AT-013.
- Related decision: DEC-062 in `one.md` defines Device Sign In as the cross-device mock, separate
  from Device Session and DBSC.
- Implementation date: 2026-10-13.

## Decisions Made During Implementation

- The frozen plan says no locale key naming the mock was found. A repository search found the
  placeholder key `sign.app.authentication.device.placeholder` and selection key
  `sign.app.authentication.new.links.device` in all four `jp`/`us`, `en`/`ja` locale bundles. Both
  keys were used only by the retired placeholder controller and selection entry, so those exact keys
  were removed from the four bundles. The frozen plan files remain unchanged.
- The pre-commit Oxfmt hook reflowed several existing long scalars in the Japanese locale bundles. A
  parsed-data comparison confirmed there were no locale value changes beyond removal of the two mock
  keys.
- The route, controller, chooser entry and mock-only controller test were removed. Existing route
  and chooser tests now assert the retired path and option are absent. No redirect or replacement
  route was added.
- Device Session, DBSC, device management, Social Login, Passkey, Secret Credential, Email OTP and
  organization emergency Passkey implementations remain outside the diff.

## Deviations From Plan

- The E2E selector was updated, but Playwright could not be run in this environment: the isolated
  Rails runner and E2E service URLs were unset, the previously used isolated runner file was absent,
  and no service listened on ports 3443, 3192 or 3188.
- The first scoped Valkey cleanup attempt exposed that `scripts/test-valkey-cleanup` does not load
  Active Support's enumerable extensions before `Valkey::Settings` calls `Array#index_with`. The
  final isolated test run preloaded `active_support/core_ext/enumerable`; scoped cleanup then
  succeeded. The cleanup script was not changed because test-harness maintenance is outside this
  retirement step.

## Review Notes

- Tests run: evidence record `evidence/2026-10-13-device-sign-in-retirement-F3X8.md`.
- Tests not run: Playwright E2E because its runner, service URLs and local proxy were unavailable;
  the full Rails suite is reserved for the later full-suite plan step.
- Documentation promotion needed: none. The discrepancy is retained here because `one.md` and
  `two.md` are frozen for this implementation.
