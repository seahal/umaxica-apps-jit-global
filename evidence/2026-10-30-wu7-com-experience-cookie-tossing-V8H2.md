# WU-7 com client experience cookie ambiguity

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A com document with two visible `__Secure-experience` cookies at different paths previously selected one. The client now requires exactly one visible cookie, both at startup and after a cookie-change event; an ambiguous projection leaves the server-rendered theme in place. A generation counter prevents an older asynchronous change read from replacing a newer one or updating after unsubscribe.
- `bun run test gait/lib/theme.test.ts gait/lib/cookies.test.ts gait/entrypoints/theme_cookie.test.ts gait/components/chrome/theme_controls.test.tsx`: 4 files, 94 tests passed. `bun run typecheck`, targeted `oxlint`, and targeted `oxfmt --check` passed.
- System Chromium 156.0.8078.73 was launched headless with its sandbox enabled against a temporary local Vite server. Cookie Store reported two same-name secure cookies at different paths; the module retained the rendered dark theme. This is a focused browser-module check, not a full Rails/browser journey. The temporary server was stopped.
- Realm-specific keys, lifecycle/schema changes and broader WU-7 checks remain incomplete. No migration or full Rails suite was run.
