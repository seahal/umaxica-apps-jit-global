# Development-only ORG Seed Operator (Bootstrap rebuild)

Status: Deferred; recorded at the user's request on 2026-10-23. Removed from the scope of the
2026-10 authentication cycle; no implementation change is authorized by this entry. Stored in
`docs/backlog/` at the user's explicit request.

## Purpose

A development-only way to obtain the first ORG Operator session, so that a fresh development
database can be operated without an existing Operator and Passkey. Production and every deployed
environment must never reach it.

## Owner decisions carried over

- The existing Bootstrap code, routes, seeds and data may be removed and replaced rather than
  adapted; destructive changes are allowed (cycle decision D-122).
- Policy (cycle decision D-13): ORG only; development only, idempotent seed; Microsoft Entra
  `(tid, oid)` identity only; no Passkey; separate controllers and callback; development and test
  routes plus an independent refusal at finalization; no Flipper or `ENV` switch enables it; a
  dedicated authentication context; minimal authorization; no Bureau, Ownership or Membership is
  created; fail-closed invitations are kept.

## Review criteria (from the cycle's critical review, R-14)

- Enumerate what makes a runtime local-only, the authoritative signal, how it is provisioned, and
  verify it again independently at finalization; refuse when it is missing or unknown.
- A credential named "development only" is not proof: the repository uses one credentials set per
  Rails environment (D-15), so a deployment started with development settings would carry it.
- The Bootstrap context must survive root, grant, refresh and Access JWT claims and every
  authorization boundary; no omission may turn it into Normal.
- Do not widen existing Operator roles. Keep seed idempotency, callback identity verification and
  session authority separate. Normal Entra callbacks keep their Passkey stage. The seed refuses
  foreign ownership and stopped identities instead of rebinding or reactivating them.
- Seed and environment setup are verified by running them and recording the result in
  `evidence/`, never by Minitest or Vitest cases about environment construction.

## Facts when recorded (static reading of commit `6e4d70d0b`)

- Nothing of the rebuild is implemented.
- `AuthenticationContextValue` knows `normal` and `standby`; `from_claim` maps a **blank claim to
  Normal** and unknown values to `UNKNOWN` (`app/values/authentication_context_value.rb:107`); its
  permit logic recognizes only Normal and Standby.
- `bootstrap_handoff` is already an Admission purpose of the Re-verification path, so the new
  feature needs another name.

## Proposed design (draft, not reviewed)

1. **Name:** "Seed Operator"; context key `seed`.
2. **Discriminator:** all of the following, checked when routes are drawn **and** again at the
   final root-login commit: `Rails.env.development?`; a credential `seed_operator.enabled_secret`
   present only in the development credentials; and a loopback TCP peer (`request.remote_addr`,
   not `remote_ip`, with no forwarding headers). Missing or unknown → refuse. No Flipper or `ENV`
   switch. The loopback peer is chosen because neither the development credentials nor a
   `*.localhost` Host header proves locality; it fails closed behind any proxy. Residual risk: a
   process on the same machine of a deployment started in development mode could still reach it.
3. **Seed:** `db:seed` in development creates one Operator bound to the configured Entra
   `(tid, oid)`; idempotent; never rebinds or reactivates a stopped Operator.
4. **Entry:** the ordinary ORG OIDC sign-in with Entra; after the Entra callback, only an Operator
   flagged as the Seed Operator skips the Passkey stage, and only while the discriminator holds.
   The ordinary issuance boundary (Admission, browser binding, cooldown, session limit, fixation
   protection) applies; nothing records Passkey, MFA or Step-Up.
5. **Context:** root, grant, refresh and Access JWT carry `seed`; `from_claim` stops mapping a blank
   claim to Normal (blank → `UNKNOWN`, which permits nothing); every authorization entry point
   allow-lists `seed` for exactly the Seed screen and Sign Out; a static guard covers the policy
   entry points.
6. **Normal Operators:** the Entra callback gains no Passkey-skip branch for anyone else.

## Tests when selected

Forged Seed callback or context; missing or unknown discriminator at the route and at
finalization; a normal Operator's callback still requiring the Passkey; refresh keeping the `seed`
context; refusal of every non-allow-listed action; blank context claim refused. Seed idempotency is
run and recorded in `evidence/`.

## Dependencies

The cycle's Visa OP move (ORG realm) and Design D relays change the ORG sign-in path this design
attaches to; design against the code as it stands when the item is selected.
