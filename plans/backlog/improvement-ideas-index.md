# Improvement Opportunities Index

This index groups the remaining ideas by theme so each note stays focused.

- [Service and runtime improvements](service-and-runtime-improvements.md)
- [Frontend and API improvements](frontend-and-api-improvements.md)
- [Infrastructure and DevEx improvements](infrastructure-and-devex-improvements.md)

## Security review follow-ups (`develop` branch, 2026-05-05)

Defense-in-depth items raised by the security review of the `develop` branch. Verified against the
working tree — most originally-listed items have already been implemented. These two remain.

- [Audit visibility boundary in `Common::Redirect` after `private` restoration](../archive/security-private-keyword-restoration.md)
- [Restore `locked_at` timestamp when OTP attempts reach threshold](security-otp-attempts-atomic-increment.md)
- [Refresh token reuse overlap window and stale cookie recovery](refresh-token-reuse-overlap-and-stale-cookie-recovery.md)
- [Refresh token race incident report and improvement plan seed](2026-09-12-refresh-token-race-incident-and-improvement-plan.md)
