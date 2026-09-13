# Apple Second Sign in with Apple Key — Portal Runbook

Deadline-critical operator procedure for
`plans/apple-google-external-authentication-architecture-audit.md` §11 Phase 0 and §12.

**This runbook contains no secret values and must never be edited to include any.** Do not paste a
`.p8` file, a client-secret JWT, a private key, a client secret, or a complete provider subject into
this file, a plan, a note, a memo, an issue, or a log line. Record identifiers in the approved
operational secret inventory and store key material only in the approved credential system.

## Why now

The Apple Developer Program renewal date shown in the account is **2026-08-06**, and the decision is
**not to renew**. Apple states that an expired membership loses access to Certificates, Identifiers
& Profiles, but does not guarantee how an already-configured web Services ID and key behave after
expiration. The correct classification is **no guarantee**, not "it keeps working" and not "it
breaks".

Every action needing Apple Developer Account access therefore has an internal deadline of:

> **2026-08-05 23:59 Asia/Tokyo**

After that boundary, assume the portal may be unmanageable: return URLs, key associations, primary
App ID, relay settings, and the notification URL can no longer be relied on to be changeable.

## Before you start

Confirm which Apple Account holds Account Holder or Admin access to the team, and confirm the
current `.p8` backup exists in approved secret storage **and can actually be restored**. A backup
that has never been restored is not a verified backup.

**The provider kill switch is not yet available as a rollback lever.**
`ExternalAuthentication::ProviderAvailabilityPort` and its environment adapter exist and are
unit-tested, but no caller invokes them while the calling style is being decided, so setting
`APPLE_SOCIAL_CEREMONY_ENABLED=false` currently stops nothing. Plan the second-key test on the
assumption that the only way to back out is to restore the previously configured key. Once the port
is wired, revisit this paragraph.

## Application-side facts to check against the portal

Recorded so the portal return URLs and client identifiers can be compared with what the application
actually sends. Source: `config/initializers/omniauth.rb`.

| Setting                     | Value                                                                                                                  |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Callback origin             | Fixed, from `PUBLIC_AUTH_SERVICE_URL`; localhost permitted outside production only. Not derived from the request host. |
| Apple callback path         | `/social/apple/callback`, `GET` only                                                                                   |
| Apple response mode / type  | `query` / `code`                                                                                                       |
| Apple scope                 | _(empty)_ — name and email are deliberately not requested                                                              |
| Apple nonce                 | Enforced at the strategy boundary; an ID token without the nonce fails authentication                                  |
| Apple notification endpoint | `POST /apple/notifications` (`config/routes/auth.rb`)                                                                  |
| Google callback path        | `/social/google/callback`                                                                                              |
| Google scope / access type  | `openid` / `online` — no refresh token is requested                                                                    |
| OmniAuth request phase      | `POST` only                                                                                                            |

Credential key names the application reads, values never displayed: `OMNI_AUTH_APPLE_CLIENT_ID`,
`OMNI_AUTH_APPLE_TEAM_ID`, `OMNI_AUTH_APPLE_KEY_ID`, `OMNI_AUTH_APPLE_PRIVATE_KEY`,
`OMNI_AUTH_GOOGLE_APP_CLIENT_ID`, `OMNI_AUTH_GOOGLE_APP_CLIENT_SECRET`.

## Procedure

### 1. Record the current configuration

Record in the approved operational secret inventory, and mark each item `complete`, `unverified`, or
`inaccessible` — never `complete` on assumption:

Team ID · primary App ID and grouping · web Services ID · all configured domains and return URLs ·
current Sign in with Apple Key ID and its primary App ID association · whether private email relay
is configured (expected: not used, because the requested scope is empty) · the displayed renewal
date and the decision not to renew · the Google OAuth client ID and its authorized redirect URIs.

Confirm the Apple return URL matches the fixed callback origin above exactly. Capture screenshots or
exports of non-secret configuration where policy permits.

### 2. Create the second key

- Create a second Sign in with Apple private key in the Apple Developer portal.
- Download the `.p8` **once** — Apple does not offer it again.
- Store it immediately in approved secret storage. Do not leave it in a downloads directory, a
  terminal scrollback, a chat message, or a repository.
- Record the second Key ID and its primary App ID association in the operational secret inventory.

### 3. Prove the second key works

- Generate a client-secret JWT using the second key. **Do not log it, print it, or persist it.** It
  is generated on demand and discarded.
- Temporarily configure the application to use the second key.
- Prove it with either a successful authorization-code exchange or a controlled production-domain
  Sign in with Apple end-to-end run.
- Record the outcome as pass or fail. Record no tokens, no authorization codes, and no complete
  subjects.

### 4. Return to the intended active key

- Restore or confirm the key the application is meant to run on after the test.
- **Retain both keys.** Do not revoke the current key before the renewal boundary.
- There is no automatic key selection and no automatic failover, by decision. Switching keys is a
  deliberate configuration change.

### 5. Confirm the deployment side

- Confirm Rails credentials contain the expected key names listed above **without displaying their
  values**.
- Confirm `PUBLIC_AUTH_SERVICE_URL` is set to the production origin registered with Apple. The
  callback origin is derived from it and fails at boot when it is missing.
- Confirm or register the server-to-server notification URL and supported TLS against
  `POST /apple/notifications`.

### 6. End-to-end confirmation

- Run a controlled production-domain Apple sign-in and record pass or fail without tokens.
- Run a **subsequent** login with the same account. This is the meaningful check: it proves the
  application does not depend on the first-login user payload, which Apple sends only once.
- Confirm at least one non-Apple authentication method is available. Passkey, email, and secret
  credential sign-in are present on the App surface.
- Confirm an Apple-only user sees the alternative-credential warning
  (`app/views/base/shared/identities/_apple_only_credential_warning.html.erb`) and that it
  disappears once another credential is added.

## If portal access is lost before completion

Do not mark unfinished portal items as complete. Instead:

- Mark each portal item `inaccessible`.
- Verify the local and deployment credential key names and the callback configuration.
- Complete the real-Gem contract tests.
- Preserve the existing `.p8` credential backup without printing or copying it into logs or
  documents.
- Record whether the second key was created, stored, and tested before access was lost.
- Leave Apple enabled on a best-effort basis unless there is a compromise or a confirmed unsafe
  failure.
- Record that return URL, key association, primary App ID, relay, and notification settings have no
  post-expiration management guarantee.

## Recording results

Report outcomes as pass, fail, or inaccessible, with no tokens and no secret values.
