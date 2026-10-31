# WU-7 read-only Warp display-cookie error

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked changes affected the result.
- Section 4.6 requires a read-only non-Base host with a valid JWT and missing or invalid display cookies to retain signed display values, emit no cookies, and record an error. Warp previously omitted that error; the new request case initially failed because no event was emitted.
- Warp now records the bounded `preference.display_cookie.unavailable` event with surface and request ID, without cookie values or JWTs. It does not write cookies. Base and Warp share the existing exact-snapshot JSON check; the check also rejects display values over 3,072 bytes before JSON parsing. Healthy display cookies produce no event.
- The expanded Warp, Base repair and Web Push selection passed: 53 runs, 695 assertions, zero failures, errors or skips. Tests cover missing, duplicate-key, oversized, language-mismatched and matching display cookies and check that synthetic sensitive values do not appear in captured error messages. RuboCop passed after wrapping two lines.
- The test observes application logging, not external exporter delivery, retention or independent browser behavior. Full-suite comparison remains outstanding. No migration or non-test purge was performed.
