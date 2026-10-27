# Non-test acceptance cases (A30-2, A05-1, A29-11, A02-14)

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree. Development databases were rebuilt
  by the owner earlier on 2026-10-27 (`db:migrate:reset` + `db:seed`).
- A30-2: `bin/rails runner` grouping `security_mode_id` — APP `Client` {3 => 2}, COM `Visitor` {} (no
  rows), ORG `Operator` {7 => 1}; `NORMAL = 3`, `ADVANCED = 7`. Passed on the development data that
  exists; the data set is small after the reset.
- A05-1: `adr/sign-up-finalization-in-auth.md` Status "Accepted … written 2026-10-24 before
  implementation (WU-05a); implemented 2026-10-24"; it has a "Supersedes" section. `git log
  --diff-filter=A` shows the ADR added in `58c52567e`, the same checkpoint commit as 98 `app/` files of
  the implementation; commit order cannot show "before". Passed on the ADR's own record.
- A29-11: `bin/rails feature_flags:status` — `sign_in_available_{app,com,org}` and
  `sign_up_available_{app,com,org}` all `availability on`. Passed for development; production check
  added to `docs/backlog/2026-10-26-pre-deployment-checks.md`.
- A02-14: kept Not run; reason updated — Jump now accepts the Visa edges for APP/ORG and the owner's
  manual APP Google journeys passed through Jump, but no recorded integration check was run.
