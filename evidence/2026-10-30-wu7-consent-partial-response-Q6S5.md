# WU-7 partial consent response

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; staged, unstaged and untracked changes affected the result.
- Added request coverage for a JSON settings-screen save that changes one previously recorded consent category. The response contains all four stored choices, and the next settings screen displays the same values. A first partial save with no prior binding also returns the new choice and a browser binding. Both cases passed without an implementation change.
- Before the test additions, the consent receipt and response-binding files passed: 15 runs, 110 assertions. Afterward the receipt, response-binding and initialization files passed: 46 runs, 581 assertions, zero failures, errors or skips. RuboCop passed after a blank-line correction.
- This covers these request paths, not all client/browser delivery or full-suite behavior. The `two.md` JWT type example and accepted RFC 9068 ADR remain inconsistent. No migration was run; WU-7 completion remains unverified.
