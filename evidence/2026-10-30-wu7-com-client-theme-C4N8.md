# WU-7 com client theme projection

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- The client theme reader previously used the retired `ct` cookie on com and could overwrite the server-rendered theme. Com now reads and watches `__Secure-experience`; missing or malformed projection preserves the rendered theme, and a `ct` URL overlay remains in effect. App/org continue reading `ct`. This projection is used only for presentation.
- `bun run test gait/lib/theme.test.ts gait/entrypoints/theme_cookie.test.ts gait/components/chrome/theme_controls.test.tsx`: 3 files, 73 tests passed. `bun run typecheck` passed. Targeted `oxlint` and `oxfmt --check` passed for the five changed TypeScript files.
- No configured browser or DevTools tool was available; real-browser behavior remains unverified. This does not implement the other experience fields or complete WU-7. No migration or full Rails suite was run.
