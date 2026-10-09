# Current Email sign-in response-time measurement

- Date: 2026-10-09 UTC.
- Commit: `809ed57629f03052ba311c8c953f4aa682c93ebf`.
- Worktree: dirty; uncommitted authentication changes and unrelated concurrent edits affected this measurement.
- Environment: the verified disposable `20261009accept1` 20-database manifest, one Rails worker, test-mode local Turnstile substitute and no real mail delivery.
- Driver: `tmp/email-sign-in-parity-probe-20261009.rb`, an ignored operational copy of the earlier parity probe. Its admission setup was updated to use the current public attachment and redemption flow. The driver completed with zero Minitest test cases; its output is a measurement, not test evidence.

After two warmups, each surface/mode/stage retained 30 HTTP observations. Real and dummy requests alternated order and used independent destinations, browser jars and caller addresses. Durations are milliseconds:

| Surface | Stage | Real median / p95 | Dummy median / p95 |
| --- | --- | ---: | ---: |
| app | receipt | 105.232 / 108.549 | 105.109 / 108.560 |
| app | entry | 10.526 / 18.792 | 10.235 / 15.218 |
| app | resend | 105.054 / 118.100 | 105.438 / 108.054 |
| app | wrong code | 106.998 / 109.874 | 106.580 / 113.968 |
| com | receipt | 105.190 / 107.431 | 105.179 / 106.349 |
| com | entry | 10.654 / 12.459 | 9.661 / 11.433 |
| com | resend | 105.229 / 108.517 | 105.187 / 106.252 |
| com | wrong code | 106.505 / 108.288 | 106.119 / 107.859 |

The app dummy wrong-code maximum was 197.048 ms, compared with 119.966 ms for real wrong-code; this local tail observation does not prove or disprove production enumeration resistance. The measurement does not cover signup, cancellation, expiry, actual transport, browser cookie enforcement or production contention. It closes only the current HTTP timing measurement clause of the Phase 19.4 investigation.
