# WU-7 com experience projection validation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- The com client now checks all eight experience fields and their allowed option names before applying its theme. Missing, unexpected, invalid and duplicate keys leave the server-rendered theme in place. To detect duplicate keys despite native JSON parsing, it accepts the compact JSON encoding produced by the current server. A Rails-generated example matched the browser's JSON round trip.
- `bun run test gait/lib/theme.test.ts gait/entrypoints/theme_cookie.test.ts gait/components/chrome/theme_controls.test.tsx`: 3 files, 77 tests passed. `bun run typecheck` and targeted `oxlint` passed; modified TypeScript files were formatted with `oxfmt`.
- System Chromium 156.0.8078.73 was launched headless with its sandbox enabled against a temporary local Vite server. The real Cookie Store API read a complete secure experience cookie as dark and retained the server-rendered light theme for a duplicate-key cookie. This was a focused module check, not a full Rails/browser journey. The temporary server was stopped afterward.
- Realm-specific keys, the lifecycle/schema changes and broader WU-7 checks remain incomplete. No migration or full Rails suite was run.
