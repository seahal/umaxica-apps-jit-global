# Command-checked acceptance cases (A02-3, A03-3, A29-10, A18-1/2)

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with the uncommitted cycle
  changes.
- A03-3 — owner ran `grep -rn "edge/v0/cookie" app config src`: no output. Passed.
- A29-10 — owner ran `rg sign_up_suspended`: matches only in `research/`, `specs/`, `adr/`, `plans/`
  and one comment in `src/features/auth/signup/SignUpMethodChoice.tsx`; no code reads the flag.
  `suspended_notice` is still declared as a prop in `SignUpMethodChoice.tsx` and
  `src/features/auth/AuthMethodChoice.tsx`, and no server code sends it (`rg suspended_notice app`:
  no match). Passed; the dead prop and stale comment are reported, not changed.
- A02-3 —
  - `env PUBLIC_VISA_{SERVICE,CORPORATE,STAFF}_URL= bin/rails runner 'puts "BOOTED"'`: each run stopped
    at boot with `ConfigValues.validate_origin_uri!: invalid origin (ArgumentError)`.
  - `bin/rails runner` building `ConfigValues::HostFamilyValues.build(env:, production: true)` from a
    complete environment, then removing each Visa key: `Missing required ENV key:
    PUBLIC_VISA_SERVICE_URL`, `… PUBLIC_VISA_CORPORATE_URL`, `… PUBLIC_VISA_STAFF_URL`. No value falls
    back to a Base origin. Passed.
  - Note: outside production, a missing key falls back to `visa.{app,com,org}.localhost`
    (`development_host`), a code-side default shared by every host family; not changed.
- A18-1, A18-2 — Deferred: WU-18c … 18f are held for a later cycle (D-175, D-195).
