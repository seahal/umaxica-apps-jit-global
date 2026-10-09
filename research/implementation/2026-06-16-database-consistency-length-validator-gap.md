# Database consistency length validation gap

## Context

The local `LengthConstraintChecker` in `lib/tasks/database_consistency_check.rake` now reports three
cases for columns with explicit length limits below the default Rails varchar size:

- missing length validator: warn
- validator maximum above the database limit: fail
- validator maximum below the database limit: warn

## Implementation note

The checker intentionally skips varchar columns with the default 255-character limit. That avoids
flagging every plain string column in the app, which would create a large amount of low-value noise.

## Models updated in this pass

- `OrganizationInvitation#code`
- `ClientAuthorizationCode#code`, `#client_id`, `#code_challenge_method`
- `VisitorAuthorizationCode#code`, `#client_id`, `#code_challenge_method`
- `OperatorAuthorizationCode#code`, `#client_id`, `#code_challenge_method`

## Follow-up

If another pass needs to broaden the checker, it should do so deliberately and with a noise budget
in mind so that default 255-character columns stay excluded unless there is a specific reason to
include them.

## Null constraint pass

In the June 16 consistency pass, the safest `NullConstraintChecker` fixes were the direct user-input
fields that already had clear model-level intent:

- `ClientEmail#address`
- `VisitorEmail#address`
- `ClientTelephone#number`
- `Organization#name`
- `Organization#domain`

I left the occurrence metadata columns with `default("")` alone for now. Those fields may still trip
the checker, but treating them as required would be a broader behavior change than this batch was
meant to absorb.
