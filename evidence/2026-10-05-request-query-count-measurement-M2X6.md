# Request Query Count Measurement on the App Surface

Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`. The worktree had many unrelated uncommitted changes; the avatar
list count below includes one query added by the uncommitted `Base::App::AvatarsController` change.

## Reason

`log/development.log` for 2026-10-05 01:00–03:14 UTC reported 23–38 queries on ordinary pages, 6 on
each preference API read, and 195 on `Base::App::Social::Authentication::CompletionsController#create`.
The preference cookie and theme endpoints were each requested twice per page load.

## Method

A temporary integration test outside the repository tree subscribed to `sql.active_record` and
tallied statements for one authenticated request each, after one warm-up request. Transaction and
schema statements were excluded. The test was not added to the suite.

## Result

| Request | Statements | Served by the query cache | Reached the database | Distinct shapes |
|---|---|---|---|---|
| `GET /dashboard` | 23 | 13 | 10 | 12 |
| `GET /api/v0/preferences/theme` | 6 | 4 | 2 | 4 |
| `GET /avatars` | 21 | 10 | 11 | 15 |

The repeated statements are the session lookups on `client_tokens` and `client_device_sessions`
(three times per page) and the selected persona, membership, and avatar lookups (twice). The repeats
are identical statements that the per-request query cache answers.

In the development log the same requests completed in 8–35 ms with 1–5 ms of database time. The
social sign-up completion took 284 ms with 20.67 ms of database time and runs once per sign-up.

The doubled preference requests come from `strictMode: true` in `src/inertia/surface.ts`: React
runs each effect twice in a development build. `ThemeControls` and `CookieBanner` are each mounted
once in `src/layouts/SurfaceLayout.tsx`.

## Conclusion

No code was changed. The counts did not show a material cost.

- Not measured: a production build, production data volumes, or concurrent load.
- Not measured: the social sign-up completion statement by statement.
