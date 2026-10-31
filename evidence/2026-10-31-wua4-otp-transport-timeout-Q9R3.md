# OTP transport timeout investigation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this investigation.
- Constructed the installed AWS SNS client with synthetic credentials and the same credential/region option types as the provider. Its effective SDK defaults were open timeout 15 seconds, read timeout 60 seconds, legacy retry mode and retry limit 3. This was not a call to AWS or a test of production configuration.
- Ran a local loopback `Net::HTTP` probe with a 0.2-second read timeout and a server sending one byte every 0.15 seconds. The response completed with HTTP 200 and six bytes after 0.75 seconds, exceeding the individual read timeout. This demonstrates that the Ruby HTTP read timeout in that probe is not a total request deadline; it does not independently prove how every SDK transport handles every failure.
- The production SMTP configuration specifies 5-second open and 10-second read timeouts. The source inspection does not establish a deadline for the complete SMTP transaction.
- No external request, application change, or delivery was made. A deadline spanning all network stages, its interaction with ambiguous delivery and existing retry behavior, and cancellation under a stalled actual provider remain unverified.
