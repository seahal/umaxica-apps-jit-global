# OTP verification token transport without plaintext fallback

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`. Uncommitted task changes affected these results.
Verification used local test delivery, not an external email service.

Six public mailer regressions reproduced acceptance of plaintext-only and mixed plaintext/encrypted
verification token fields across APP/COM/ORG: six failures, seed 11880. All three concrete mailers
now reject the legacy field before transport, including when an encrypted token is also supplied.
An absent optional encrypted verification token still means no verification link, not an alternate
credential source. Existing adapters and Noticed issuance already encrypt the token before queueing.

The focused regressions passed six runs and 24 assertions, seed 62665. The expanded mailer,
suspension-interceptor, Noticed and Auth-bound late-delivery matrix initially reproduced one missing
sign-in state fixture under 16-process execution, seed 36257. The Noticed test now prepares its own
required semantic states; legacy fixture inputs now use actual production encryption. The expanded
matrix passed 53 runs and 302 assertions, seed 15090, without failures, errors or skips.
Seven-file focused RuboCop passed. Three touched mail-link environment reads also lost their
code-side defaults, retaining the normal configured-host contract.

This removes the directly encountered verification-token compatibility path, not every remaining
Source HOTP caller or counter-bound transport. The complete ownership migration remains open.
