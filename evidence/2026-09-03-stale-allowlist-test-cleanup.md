# Stale allowlist test cleanup after dead-controller removal

Date: 2026-09-03
Command: `bin/rails test`
Result: 12166 runs, 66744 assertions, 0 failures, 0 errors, 1 skip (412.86s)

## Cause

`develop` removed unrouted controllers. Security contract tests still listed those paths.

## Changes

- Removed `base/{app,com,org}/edge/v0/dbsc_controller.rb` from `RI_SKIP_ALLOWLIST` and `SENSITIVE_SKIP_ALLOWLIST`.
- Removed the same paths from the withdrawal-gate skip allowlist.
- Removed deleted `clients`/`operators` emergency revocation controllers from `KNOWN_VIOLATIONS` and Action Policy mutation exceptions. `visitors` remains (still present and routed).
- Deleted `test/controllers/base/org/edge/v0/dbsc_controller_test.rb` (class no longer exists).
