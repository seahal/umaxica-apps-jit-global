# Telephone credential-registration resend scope

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting the operation and tests.
- A temporary public-operation probe issued an APP Telephone credential-registration OTP and immediately invoked its resend issuer with the original actor, Root, browser and transaction. Both calls succeeded and the OTP generation changed (1 run, 5 assertions). The probe was removed.
- The source search `rg -n 'TelephoneCredentialRegistrationOtpResendIssuer' app` found only the issuer class declaration; direct invocation in tests does not establish an HTTP or production caller, actual SMS delivery, or absence of dynamic dispatch.
- The accepted realm-separated-identifiers ADR states that Telephone registration does not import Email cooldown or bootstrap policy, and `two.md` limits the D-58 ordering to the named sign-in/signup paths. These facts do not by themselves settle whether a separate Telephone-specific resend rate boundary is required at a caller. No implementation or response contract was changed.
