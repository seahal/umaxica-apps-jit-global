# Credential Abuse Rate Limits

This document defines the stable counting model for credential abuse controls. It applies to rate
limits, cumulative delivery limits, credential inventory caps, and similar authentication-resource
limits across the `app`, `com`, and `org` surfaces.

Current implementation values remain the source of truth for each specific operation until a rule is
documented here and backed by implementation.

## OAuth Authorize Request Windows

The Base authorization endpoint evaluates its surface-local IP, browser/client, and
client/redirect-host windows in that order. Each counter result must be a positive integer. A count
at or below the configured inclusive maximum continues; a count above it returns HTTP 429 and stops
later checks. A missing or malformed counter result, or an explicit Valkey availability/operation
error, returns HTTP 503 and does not continue authorization. There is no process-local or alternate
backend fallback. Operational failures use the `oidc.authorize.rate_limit.backend_failure` log event;
the exception message and counter value are not logged.

The current limits are owned by `RateLimitProfiles.oauth_authorize`; this document does not create a
second numeric policy source or a new alert threshold.

This document covers Rails semantic rate limits and related application-aware rejection logic. It
does not define CloudFront, AWS WAF, ALB, security-group, or task-local firewall policy. Those
network and edge controls are owned by the CDN / AWS edge boundary described in
`adr/dos-and-firewall-controls-at-cdn-aws-edge-not-in-rails.md`.

## Standard Time Windows

Rate-limit policy tables use these time windows:

| window   | purpose                                            |
| -------- | -------------------------------------------------- |
| 1 sec    | burst control, double-submit and bot dampening     |
| 1 min    | user-visible resend and retry pacing               |
| 1 hour   | short attack-rate control                          |
| 1 day    | daily cost and abuse budget                        |
| 1 week   | repeated abuse across several days                 |
| 1 month  | billing-period and identifier-churn limits         |
| 1 year   | long-term abuse history                            |
| all time | current-state inventory caps and permanent history |

These windows are the policy units for `events / time` limits. A single event may be counted under
multiple windows and multiple subjects.

## Count Domain

All counters and count limits are finite non-negative integers.

```text
0 <= count <= 1e18
0 <= limit <= 1e18
```

In this document, `1e18` is exact notation for:

```text
1,000,000,000,000,000,000
```

It is not a rounded physical quantity, floating-point value, or approximation. The upper bound is
intentionally lower than PostgreSQL `bigint` max `9,223,372,036,854,775,807` and leaves
implementation headroom.

`1e18` is not infinity. The model does not use infinity.

Do not use negative values, floating-point values, decimal values, `nil`, or sentinel values such as
`-1` to represent a counter or count limit.

Policy tables may use `-` in a limit cell. `-` means this event/subject/window combination is not
checked. It is not a count value and must not be persisted as a counter. Implementations should
normalize `-` into rule absence before evaluating limits so controllers and callers do not need
per-window branching.

Only the policy-loading boundary may interpret raw `-` cells. Controllers, services, and limit
evaluators must not branch on `value == "-"`, `nil`, blank strings, or other sentinel-like values.
After normalization, a window has either a finite non-negative integer limit or no rule.

For checked windows in the same event / subject row, limits must be monotonic as the time window
gets longer:

```text
1 sec <= 1 min <= 1 hour <= 1 day <= 1 week <= 1 month <= 1 year <= all time
```

`-` cells are skipped for this comparison because they mean the window is not checked. A longer
checked window must not have a lower limit than a shorter checked window for the same event and
subject.

## Counting Shape

Every abuse-control rule should be expressible as:

```text
event, subject, window, limit, counter_source
```

For a given rule:

```text
allow iff count < limit
```

For a `-` cell, there is no rule for that window and the check is skipped.

Implementations that increment before checking, reserve capacity, or use a different comparison
order must document that behavior with the rule.

## Counter Sources

Every rule must declare the source used to decide whether the count is within the limit. Multiple
storage systems may exist, but the enforcement source for each row must be explicit.

| counter_source | intended use                                               |
| -------------- | ---------------------------------------------------------- |
| valkey         | short rolling windows, burst control, request-rate limits  |
| occurrence     | durable delivery and identifier-target counters            |
| chronicle      | actor-visible security history and audit-backed decisions  |
| credential_db  | current-state inventory caps on credential tables          |
| token_db       | session and token inventory caps                           |
| provider       | outbound provider-side quotas when exposed by the provider |
| pending        | target row without an implemented enforcement source yet   |

Short windows such as `1 sec` and `1 min` usually use `valkey`. Long windows such as `1 day`,
`1 month`, `1 year`, and `all time` should prefer a durable source when the decision affects cost,
security posture, or support review. SMS cost controls should not rely only on cache state for daily
or longer windows.

## Subjects

Rules should count the narrowest relevant subject and may layer broader subjects when needed:

| subject          | use case                                      |
| ---------------- | --------------------------------------------- |
| actor            | signed-in user, visitor, or operator limits   |
| session          | browser or flow-local pacing                  |
| ip               | anonymous abuse and burst control             |
| ip_prefix        | distributed abuse from nearby addresses       |
| email_digest     | email target limits without storing raw email |
| phone_digest     | SMS target limits without storing raw number  |
| provider_uid     | social identity link or sign-in limits        |
| provider_account | outbound provider account cost budget         |

Raw email addresses, telephone numbers, OTPs, tokens, cookies, authorization headers, and full
request params must not be used in logs or durable counter keys.

## SMS Guidance

SMS delivery is an externally expensive event. SMS send rules should be layered at least by
`phone_digest`, `actor` or `session` when available, and `ip`.

Current short-window Rails telephone verification uses a privacy-safe composite Valkey key made from
the request IP address and the telephone blind-index digest. The key is identifier-aware without
placing a raw telephone number in cache keys or logs, and it avoids blocking every user behind the
same NAT solely because one telephone target exceeded its pacing limit.

The expected policy shape is:

```text
sms.otp.send / phone_digest / 1 sec
sms.otp.send / phone_digest / 1 min
sms.otp.send / phone_digest / 1 hour
sms.otp.send / phone_digest / 1 day
sms.otp.send / phone_digest / 1 week
sms.otp.send / phone_digest / 1 month
sms.otp.send / phone_digest / 1 year
sms.otp.send / phone_digest / all time
```

The concrete limits for these rows must be documented once implemented.

## Count Limit Tables

Count limit tables must use the standard time windows and the finite count domain defined above.
Rows with `implementation: target` are intended policy values and must not be treated as enforced
until the source column points to implemented code.

### Outbound OTP Delivery Targets

| event          | subject      | 1 sec | 1 min | 1 hour | 1 day | 1 week | 1 month | 1 year | all time | counter source | implementation | source  |
| -------------- | ------------ | ----: | ----: | -----: | ----: | -----: | ------: | -----: | -------: | -------------- | -------------- | ------- |
| sms.otp.send   | phone_digest |     - |     2 |      5 |    10 |     30 |      60 |    300 |   10,000 | occurrence     | target         | pending |
| sms.otp.send   | session      |     - |     2 |     10 |    20 |     80 |     200 |   1000 |     1e18 | valkey         | target         | pending |
| sms.otp.send   | actor        |     - |     2 |     10 |    20 |     80 |     200 |   1000 |     1e18 | chronicle      | target         | pending |
| sms.otp.send   | ip           |     - |     5 |     50 |   200 |   1000 |    3000 |  30000 |     1e18 | valkey         | target         | pending |
| email.otp.send | email_digest |     - |     1 |     10 |    30 |    100 |     300 |   3000 |     1e18 | occurrence     | target         | pending |
| email.otp.send | session      |     - |     3 |     20 |    50 |    200 |     600 |   6000 |     1e18 | valkey         | target         | pending |
| email.otp.send | actor        |     - |     3 |     20 |    50 |    200 |     600 |   6000 |     1e18 | chronicle      | target         | pending |
| email.otp.send | ip           |     - |    10 |    100 |   500 |   2000 |    6000 |  60000 |     1e18 | valkey         | target         | pending |

These values are deliberately stricter for SMS than email because SMS has direct per-message cost.
Target-specific limits (`phone_digest`, `email_digest`) are the primary controls. Session, actor,
and IP limits are layered controls for replay, compromised sessions, and anonymous abuse.

### Registered Email Address Change Targets

Registered email address changes are account-recovery and account-takeover sensitive. The primary
rule is actor-based and follows the public-platform style constraint of at most four registered
email address changes per hour.

| event                            | subject      | 1 sec | 1 min | 1 hour | 1 day | 1 week | 1 month | 1 year | all time | counter source | implementation | source  |
| -------------------------------- | ------------ | ----: | ----: | -----: | ----: | -----: | ------: | -----: | -------: | -------------- | -------------- | ------- |
| credential.email.register.change | actor        |     - |     2 |      4 |     8 |     20 |      40 |    200 |    1,000 | chronicle      | target         | pending |
| credential.email.register.change | email_digest |     - |     2 |      4 |     8 |     20 |      40 |    200 |    1,000 | occurrence     | target         | pending |
| credential.email.register.change | session      |     - |     2 |      4 |     8 |     20 |      40 |    200 |     1e18 | valkey         | target         | pending |
| credential.email.register.change | ip           |     - |     5 |     20 |    80 |    200 |     500 |   2000 |     1e18 | valkey         | target         | pending |

This event means changing the registered email address for an existing account, not adding a
secondary email credential or sending an email OTP. Each surface must map this event to its own
current account model and route boundary.

### Registered Email Address Creation Targets

Registered email address creation covers adding a new email credential to an existing account. This
is separate from email OTP delivery and from changing which email address is treated as the
registered email address.

| event                         | subject      | 1 sec | 1 min | 1 hour | 1 day | 1 week | 1 month | 1 year | all time | counter source | implementation | source  |
| ----------------------------- | ------------ | ----: | ----: | -----: | ----: | -----: | ------: | -----: | -------: | -------------- | -------------- | ------- |
| credential.email.register.new | actor        |     - |     2 |      5 |    10 |     30 |      60 |    300 |     1e18 | chronicle      | target         | pending |
| credential.email.register.new | email_digest |     - |     2 |      5 |    10 |     30 |      60 |    300 |    1,000 | occurrence     | target         | pending |
| credential.email.register.new | session      |     - |     2 |      5 |    10 |     30 |      60 |    300 |     1e18 | valkey         | target         | pending |
| credential.email.register.new | ip           |     - |     5 |     20 |    80 |    200 |     500 |   2000 |     1e18 | valkey         | target         | pending |

This event maps to configuration email registration flows such as `/settings/emails/registration`,
not public sign-up email registration.

### Email Sign-In Targets

Email sign-in has two separate events: issuing the sign-in OTP and verifying the submitted code.
Issuance affects outbound delivery cost and account enumeration risk. Verification affects brute
force risk and should remain bounded even when no email is sent.

| event                     | subject      | 1 sec | 1 min | 1 hour | 1 day | 1 week | 1 month | 1 year | all time | counter source | implementation | source  |
| ------------------------- | ------------ | ----: | ----: | -----: | ----: | -----: | ------: | -----: | -------: | -------------- | -------------- | ------- |
| auth.email.sign_in.issue  | email_digest |     - |     2 |     10 |    30 |    100 |     300 |   3000 |     1e18 | occurrence     | target         | pending |
| auth.email.sign_in.issue  | session      |     - |     3 |     20 |    50 |    200 |     600 |   6000 |     1e18 | valkey         | target         | pending |
| auth.email.sign_in.issue  | ip           |     - |     5 |     50 |   200 |   1000 |    3000 |  30000 |     1e18 | valkey         | target         | pending |
| auth.email.sign_in.verify | email_digest |     - |     5 |     20 |    60 |    200 |     600 |   6000 |     1e18 | occurrence     | target         | pending |
| auth.email.sign_in.verify | session      |     - |     5 |     20 |    60 |    200 |     600 |   6000 |     1e18 | valkey         | target         | pending |
| auth.email.sign_in.verify | ip           |     - |    10 |    100 |   500 |   2000 |    6000 |  60000 |     1e18 | valkey         | target         | pending |

This table covers email sign-in for the surfaces that expose email sign-in. It does not define org
operator email sign-in unless that route is explicitly introduced.

### Birthdate Registration Targets

Birthdate is an encrypted account profile attribute, not an outbound delivery event. Current
self-service configuration pages expose birthdate as read-only after step-up. Initial birthdate
collection happens during sign-up checkpoint flows.

Birthdate values use the exact `YYYY-MM-DD` text form: four-digit year, two-digit month, and
two-digit day, ten characters total. The format validator accepts only years `1900..9999`, months
`01..12`, and days `01..31`. It does not reject calendar-impossible dates such as `1900-02-29`,
`2000-02-31`, or `2000-04-31`. The relative-date validator separately requires the value to be
before the registration date; the current date is not accepted.

UI collection may be stricter than the stored structural domain. Current sign-up checkpoint forms
use native date inputs, which typically prevent users from entering calendar-impossible dates even
though the model can store structurally valid `YYYY-MM-DD` text. Existing-account birthdate changes
should not be ordinary self-service edits. Future change flows should require high-assurance
step-up, expected to be AAL3-equivalent for this application, and an identity-verification path
before support or system code updates the stored value.

The actor models store birthdate with Rails Active Record Encryption. Encryption at rest reduces
plaintext database disclosure risk, but it does not make birthdate non-sensitive: application-key
compromise, application-level reads, logs, exports, and support tooling still need ordinary
sensitive-data handling. Raw birthdate values must not be used in durable counter keys or logs.

| event                             | subject        | 1 sec | 1 min | 1 hour | 1 day | 1 week | 1 month | 1 year | all time | counter source | implementation | source  |
| --------------------------------- | -------------- | ----: | ----: | -----: | ----: | -----: | ------: | -----: | -------: | -------------- | -------------- | ------- |
| profile.birthdate.register.new    | actor          |     - |     - |      - |     - |      - |       - |      - |        1 | credential_db  | target         | pending |
| profile.birthdate.register.new    | sign_up_ticket |     - |     - |      - |     - |      - |       - |      - |        1 | token_db       | target         | pending |
| profile.birthdate.register.new    | session        |     - |     - |      5 |    10 |     20 |      40 |    200 |     1e18 | valkey         | target         | pending |
| profile.birthdate.register.new    | ip             |     - |     - |     20 |    80 |    200 |     500 |   2000 |     1e18 | valkey         | target         | pending |
| profile.birthdate.register.change | actor          |     - |     - |      - |     - |      - |       - |      - |       10 | credential_db  | target         | pending |

`profile.birthdate.register.new` means accepting the initial birthdate value during sign-up. It
counts accepted writes, not every invalid form submission. `all time = 1` reflects that a completed
account should only receive one self-service initial birthdate.

`profile.birthdate.register.change` means changing the birthdate of an existing signed-in account.
The target self-service policy allows a finite lifetime number of changes, similar to public
platforms that cap birthdate rewrites. Current implementation still exposes read-only configuration
pages, so this row remains a target until a change flow is implemented.

### Existing Implemented Controls

| event or control              | subject | 1 sec |   1 min |  1 hour | 1 day | 1 week | 1 month | 1 year | all time | counter source | implementation | source                                                                                                                      |
| ----------------------------- | ------- | ----: | ------: | ------: | ----: | -----: | ------: | -----: | -------: | -------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------- |
| default web request limit     | ip      |  1e18 |     300 |    1e18 |  1e18 |   1e18 |    1e18 |   1e18 |     1e18 | valkey         | implemented    | `app/controllers/{acme,core,sign}/*/application_controller.rb` (`default_web`)                                              |
| telephone verification create | ip      |  1e18 |       5 |    1e18 |  1e18 |   1e18 |    1e18 |   1e18 |     1e18 | valkey         | implemented    | `app/controllers/concerns/sign/telephone_registrable.rb`, `app/controllers/concerns/sign/operator_telephone_registrable.rb` |
| sign-in OTP resend            | target  |  1e18 | dynamic | dynamic |  1e18 |   1e18 |    1e18 |   1e18 |     1e18 | occurrence     | implemented    | `app/services/sign/in/otp_resend_policy.rb`                                                                                 |

`dynamic` means the implementation uses recent event history and exponential cooldown instead of a
single fixed count for that window.

The `default web request limit` is a surface-wide baseline declared on each surface-local
`ApplicationController` (scope `<surface>_default_web`, e.g. `acme_app_default_web`). The
`RateLimit` concern (`app/controllers/concerns/rate_limit.rb`) is a side-effect-free helper —
including it does not install any rate limit; the limit and its numeric value are declared on the
inheriting controller via the Rails-native `rate_limit` DSL. Per-endpoint limits in the rows below
stack on top of this baseline as defense-in-depth.

## Related

- `adr/finite-nonnegative-rate-limit-counts.md`
- `docs/security/session-limit.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `plans/backlog/credential-abuse-rate-limit-policy.md`
