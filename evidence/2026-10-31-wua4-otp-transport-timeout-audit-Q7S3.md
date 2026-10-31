# OTP transport and cancellation boundary inspection

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the inspected code.
- Source inspection found that the APP signup Email and telephone delivery guards hold the Flow lock while invoking their transport blocks. The Email mailer supplies its delivery block to the guard; the SMS job calls `OutboundSms.deliver_now` within the telephone guard.
- Production SMTP configuration specifies open and read timeouts of 5 and 10 seconds. The SNS provider does not pass explicit HTTP timeout or retry options. A local, stubbed `Aws::SNS::Client` constructed with dummy credentials reported open timeout 15 seconds, read timeout 60 seconds, retry mode `legacy`, and max attempts 3; this did not contact AWS or inspect deployed configuration. The installed SDK's connection pool source also states 15- and 60-second open/read defaults.
- This inspection does not establish an overall wall-clock deadline, deployed SDK configuration, the duration of retries, actual provider behavior, or the cancellation/delivery race. No independent-connection race was executed in this check.
