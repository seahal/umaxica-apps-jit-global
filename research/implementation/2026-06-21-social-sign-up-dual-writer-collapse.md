# Social Sign-Up Dual-Writer Collapse

## Status

Completed for the social app flow.

## What Changed

- Sign callback validation still runs on `/social/google/callback` and `/social/apple/callback`.
- Sign now stops at ceremony evidence and redirect handoff for social sign-up.
- Acme remains the only durable writer for social sign-up completion.
- `google` is the runtime provider name for the public social routes; `google_app` remains legacy
  compatibility data only.

## What Remains

- Email authority inversion is still pending.
- Telephone authority inversion is still pending.
- No public route changes were introduced.

## Verification

- Sign social callback tests pass.
- Acme social completion and provisioner tests pass.
- Route contract checks still show no runtime `/auth/*` routes.
