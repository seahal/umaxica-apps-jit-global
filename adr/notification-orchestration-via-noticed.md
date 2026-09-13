# Notification Orchestration Via Noticed

Accepted: 2026-08-07

## Supersedes

`adr/outbound-message-delivery-interface.md`, on the naming and entry-point questions only. Its
payload shape, its result object, and its rule that sensitive values are encrypted before entering
job arguments are all carried forward unchanged.

## Context

Message delivery is routed by hand-written adapters under `app/adapters/`. `OtpAdapter.for` maps a
surface and a channel to `OtpEmailAdapter` or `OtpTelephoneAdapter`, and `NoticeAdapter` and
`PromotionAdapter` do the same for their message kinds. Each adapter then calls a transport: a
surface mailer, `OutboundSms`, or eventually `ApplicationPushNotification`.

The boundary those adapters draw is sound, and the transports behind it are where the operational
controls live: `OutboundEmailSuspensionInterceptor` stops all mail, `OutboundSms` stops all SMS,
`ApplicationPushNotificationJob` stops all push, and `OutboundSensitivePayload` keeps OTP codes and
SMS bodies out of job arguments.

What the adapters do not express is the layer above them. There is no single object that answers
"this event happened, so these people are notified, over these channels". Every call site chooses
one surface and one channel, and a message that should fan out to two channels has no home. The
adapters also duplicate a fan-out and configuration mechanism that a maintained library already
provides.

`adr/outbound-message-delivery-interface.md` reserved the name `Notification` away from external
message delivery, so that in-app notification records, notification preferences, and a notification
centre could use it. It also required that call sites go through `Outbound::*` rather than choose
`deliver_later` themselves. Adopting Noticed conflicts with the first rule directly: its vocabulary
is `Notifier`, `Notification`, and `deliver_by`.

## Decision

Adopt `noticed` as the notification orchestration layer, above the existing transports.

A notifier decides which message goes to whom over which channels. Notifiers live in
`app/notifiers/` under the `Notify` namespace, with the surface as the second segment, matching
`Email::App::OtpMailer` and the controller tree: `Notify::App::OtpNotifier`,
`Notify::Com::OtpNotifier`, `Notify::Org::OtpNotifier`. `Notify` is a verb, so the noun
`Notification` stays available for in-app notification records as the superseded ADR intended.

Each surface gets its own notifier rather than one notifier taking `surface:` as a parameter. A
parameterized notifier would carry the trust boundary as a string through ActiveJob, which turns a
surface mix-up into a runtime data bug on a job payload instead of a load-time constant error. The
surfaces already diverge — only the app OTP mail builds a verification URL — and they will diverge
further.

Transports are not replaced. A delivery method calls the existing surface mailer, `OutboundSms`, or
`ApplicationPushNotification`. Consequently:

- Kill switches stay where they are and are not duplicated in a `config.if`. Mail sent through
  Noticed still passes `OutboundEmailSuspensionInterceptor`, because the interceptor keys off
  `message.delivery_handler`, which is still the surface mailer.
- Sensitive payloads are encrypted with `OutboundSensitivePayload` **before** `Notifier.with` is
  called, in the caller's process. Noticed serializes `params` verbatim into the delivery job, so
  this is the only point at which plaintext can be kept out of the job arguments. The recipient's
  address is read from the recipient inside the delivery method's `params` proc, at perform time, so
  it does not reach the job arguments either.
- The Noticed email delivery method is configured without `enqueue`, so it calls `deliver_now`
  inside the Noticed job. One message remains one job.

Only `Noticed::Ephemeral` is used. This application has no in-app notification records, so
`noticed_events` and `noticed_notifications` do not exist and no migration is added. Introducing
those tables would require choosing a database in a multi-database application and would create an
in-app notification store that no feature has asked for.

`Noticed::Ephemeral#deliver` does not call `validate!`, so a declared `required_params` is inert and
a missing parameter would be a silent no-op. Each notifier therefore validates its own arguments and
raises `ArgumentError`.

Migration is per surface behind a `:rollout` polarity feature flag registered in `FeatureFlags`:
`otp_email_notifier_app`, `otp_email_notifier_com`, `otp_email_notifier_org`. An unset flag, an
unwritten flag store, or an unreachable one all keep the shipped adapter path. This is the opposite
polarity from the outbound suspensions, and deliberately so: losing a suspension flag must not take
the product down, and losing a rollout flag must not move live traffic onto new code. The branch
lives in `OtpAdapter.for`, the single point every OTP call site already passes through, so no call
site changes during the rollout.

## Consequences

- `Outbound::*`, `OutboundSms`, the surface mailers, and `ApplicationPushNotification` are the
  transport layer. They keep their payload shape, their result object, and their kill switches. What
  changes is that notifiers, not domain call sites, address them.
- The rule that call sites must not choose `deliver_later` or a provider service directly still
  holds; the entry point they use is now a notifier.
- `Noticed::ApplicationJob` declares `discard_on ActiveJob::DeserializationError`, so a recipient
  destroyed between enqueue and perform drops the message. `ApplicationJob` behaves the same way
  today, so this is not a regression, but it is now a property of every notifier.
- `OtpEmailAdapter`, `OtpEmailNotifierAdapter`, `OtpEmailNotifierRollout`, and the three rollout
  flags are temporary. They are removed once every surface has baked and the call sites address the
  notifiers directly.
- `NoticeAdapter` and `PromotionAdapter` have no production callers. They are replaced rather than
  migrated.
- SMS needs a custom delivery method calling `OutboundSms.deliver_now`, not `deliver_later`, because
  the delivery method is already inside a job. The SMS body encryption boundary moves into the
  notifier as a result. That is a separate decision and is not settled here.
