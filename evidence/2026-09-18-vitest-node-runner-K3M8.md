# Vitest runner uses Node, not Bun

Date: 2026-09-18.

`package.json` `test` and `test:watch` now invoke `node node_modules/vitest/vitest.mjs`, matching
`test:coverage`. jsdom's EventTarget brand check fails inside Bun worker threads; Node does not.

Command: `bun run test`  
Result: exit 0. Vitest 5.0.1. 85 files, 1057 tests passed. Duration 11.02s. Node 24.20.0.

The earlier `bun --bun vitest run` baseline in this session was exit 1 (22 files / 288 tests, 63
jsdom worker start errors). That command was not re-run after the script change; the canonical
entrypoint is now Node.
