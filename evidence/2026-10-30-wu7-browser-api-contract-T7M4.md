# WU-7 browser preference API contract

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- Before the test adjustment, the two selected contract cases had one failure and one error: the theme test used HTTP while expecting the Secure com cookie, and the cross-realm case attempted to generate an invalid com token using a partial legacy snapshot and unrelated host.
- The theme case now uses HTTPS. The cross-realm case issues a real com token through the API, verifies its decoding on a same-TLD sibling, and verifies rejection and default theme reads on both app and org. The selected cases passed: 2 runs, 233 assertions. The complete browser API contract file passed: 16 runs, 2,522 assertions, zero failures, errors or skips. RuboCop passed for this file and the refresh recovery matrix.
- Full-suite comparison remains outstanding. No production or Neon database was targeted.
