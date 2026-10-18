# Vitest coverage threshold verification

Verified against commit `9c6a0fcaee7d88e94892e2b24f2b2dbe70c89c1e` with uncommitted test additions and edits affecting these results. Existing unrelated changes to `adr/frozen-string-literals.md` and deletion of `nine.md` were preserved.

Added public behavior coverage for secret listing, issuance, rename and revocation forms; issuance checkpoint and storage acknowledgement states; secret clearing on page exit, cached restoration and submission; empty document language; absent landmark metadata; and bootstrap submission without a CSRF field. Production source and coverage thresholds were unchanged.

- `bun run test --coverage`: passed, 101 test files and 1156 tests; exit code 0.
- Statements: 99.77% (2169/2174).
- Branches: 99.02% (1528/1543).
- Functions: 99.44% (722/726).
- Lines: 99.76% (2130/2135).
- Scoped `oxlint` and `oxfmt --check` on the five changed test files: passed.
- `git diff --check`: passed.

These are global coverage measurements; individual files can remain below 99%.
