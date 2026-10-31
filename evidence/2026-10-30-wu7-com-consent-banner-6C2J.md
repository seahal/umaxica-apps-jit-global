# WU-7 com consent banner

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting these checks.

The React cookie banner previously read the legacy JavaScript-visible consent buffer on every surface. With that cookie set and the com consent endpoint unavailable, its initial hidden state could persist without a verified browser-binding response. For com, the banner now starts visible and does not read the legacy buffer; it hides when the com endpoint confirms `show_banner: false`. App/org retain their existing buffer path.

Before the change, `bun run test gait/components/chrome/cookie_banner.test.tsx` passed 19 tests. After the change, `bun run test gait/components/chrome/cookie_banner.test.tsx gait/controllers/cookie_banner_controller.test.ts` passed 40 tests. New cases cover a legacy consent cookie with a failed API request and a confirmed matching-binding response. Local `oxfmt --check` and `oxlint` passed for both changed files. The first attempted lint command used unavailable `bunx`; the checked-in executables were then run directly.

No configured browser or DevTools tool was available, so real-browser rendering and interaction were not verified. The reader-host link-only banner and the broader WU-7 contract remain incomplete or unverified.
