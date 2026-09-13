# Outbound Message Delivery Interface

Accepted: 2026-05-18

## Status

Partially superseded by `adr/notification-orchestration-via-noticed.md` on 2026-08-07.

This ADR is retained for traceability. Its payload shape (`to`, `title`, `body`), its
`Outbound::Result` return value, and its requirement that sensitive payloads be encrypted before
entering job arguments remain in force. Superseded are the reservation of the `Notification` name
away from message delivery and the requirement that domain call sites address `Outbound::*`
directly; notifiers are now the entry point, and `Outbound::*` is the transport they call.

## Context

The application sends messages through several external channels, including email and SMS today, and
may later add Web Push, LINE, WhatsApp, or similar transports.

The app also has user-facing notification concepts. External message delivery should not reuse the
`Notification` name because it can be confused with in-app notification records, notification
preferences, or notification-center UI.

Current email call sites know transport-specific details such as Action Mailer and `deliver_later`.
There is no active outbound email service entry point yet. SMS call sites use the outbound SMS entry
point so provider details stay behind the outbound boundary.

## Decision

Use the `Outbound` namespace for external message delivery entry points.

Channel services live under `app/services/outbound/` and expose a class-method service interface:

```ruby
Outbound::Sms.deliver_later(to:, title:, body:)
```

The shared payload fields are:

- `to`: channel-specific recipient address or identifier.
- `title`: message title, subject, or summary. Channels that do not need it may ignore it.
- `body`: message body.

Channel services return `Outbound::Result`, which records whether the message was accepted by the
application-level outbound layer, the channel, an optional provider message id, and an optional
error.

The outbound interface does not decide business state. It must not verify accounts, mutate
registration state, or implement notification preferences. Domain flows remain responsible for
business decisions, and call `Outbound::*` only for external delivery side effects.

Whether a channel uses Solid Queue, Action Mailer, provider SDKs, or synchronous delivery is an
implementation detail of that channel service. Callers should not choose `deliver_later`,
`perform_later`, or a provider-specific service directly for new external message delivery code. SMS
delivery uses Solid Queue by default and selects the concrete provider with `SMS_PROVIDER`.
Sensitive payloads, including SMS bodies and email OTP values, are encrypted before being placed in
background job arguments.

## Consequences

- Future email, Web Push, LINE, or WhatsApp delivery can share the same call shape when their
  outbound services are introduced.
- In-app notification concepts remain free to use notification-specific names.
- Existing mailer call sites are not migrated by this decision.
- `Outbound::Sms` performs real delivery through the configured provider. `aws_sns` uses Amazon SNS,
  while `test` accepts the message without calling an external provider.
