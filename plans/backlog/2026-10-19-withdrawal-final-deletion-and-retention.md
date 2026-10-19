# Final Deletion and Retention Contracts After Withdrawal

Recorded 2026-10-19. Deferred out of the three.md cycle by user decision.

## Current state

- Retention purge records an explicit deferral for data without a settled deletion contract and
  keeps that data. No irreversible deletion is inferred from the 31-day principal deadline.
- The Passkey Chronicle retention period is TBC. Development uses a 365-day `security` policy as a
  development-only value.

## Decision needed

- Final deletion of Avatar images, Avatar ownership history and related records.
- External object storage, backups and CDN retention.
- Chronicle retention for Passkey and other lifecycle facts.
- Jurisdiction-specific legal holds and processor notification.

## Affected

three.md U11/U13; two.md REQ-R01-R07; four.md AC-P10, AC-P12, AC-V07, AC-R01-AC-R07; six.md.
