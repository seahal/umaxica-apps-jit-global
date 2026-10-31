# WU-7 com preference OpenAPI contract

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- The focused contract and route coverage selection initially failed twice: the com Web Push routes were missing from the description and the com consent response was expected to be 204 although the implementation returned 200 with JSON.
- Updated the com source and bundled OpenAPI descriptions for Web Push, the consent response and same-TLD preference behavior. Updated the existing contract test and added Web Push success and validation-response checks. The same selection then passed: 3 runs, 30 assertions, zero failures, errors or skips. `node_modules/.bin/redocly lint com` passed. RuboCop corrected three test formatting offenses.
- The full suite and the remaining WU-7 acceptance checks were not re-run in this slice.
