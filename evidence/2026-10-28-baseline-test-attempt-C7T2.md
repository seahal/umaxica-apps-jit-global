# Baseline test attempt

- Baseline commit: `b6e7871073bdc43a55fc5f05e8476de8ee71252f` (detached worktree `/tmp/umaxica-baseline-b6e787`). Main checkout HEAD: `336811e5072a93c0523e484f905082635b28f48f`, with an unrelated untracked backlog document.
- `bin/rails test` initially stopped before test execution because the isolated checkout lacked the bundle. Retried with `BUNDLE_PATH=/home/global/workspace/vendor/bundle` and a link to the existing `vendor/fork` dependencies. The process repeatedly launched `vite build --mode test` without producing test results; it was interrupted. The cause was not established.
- No test pass/failure/skip baseline was obtained. The detached checkout uses different local configuration and dependencies from the main checkout. No application implementation or database migration was performed by this work.
