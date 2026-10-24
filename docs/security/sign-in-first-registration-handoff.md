# Sign In First: Registration Handoff

This document explains why a completed App or Com registration enters the canonical Sign In
admission before any signed-in session exists. It describes the intended contract; it is not a
completion report for the current working tree.

```text
App/Com Sign Up
  identity/contact proof -> credential registration -> checkpoints
                         |
                         v
              durable registration completion
                         |
                         v
             canonical Sign In admission
              guardrail / MFA / selector / limits
                         |
                         v
                 Visa Root Session and OIDC result
                         |
                         v
                    RP-local Session
```

Auth owns credential ceremonies and authentication evidence. Visa owns the Root Session, OIDC
authorization transaction and authorization code. Base receives the browser-RP result and owns only
its RP session. An Auth flow that happens to be called from Sign In is not a second Session issuer.

The handoff is a trusted internal transition bound to the completed registration operation, actor,
browser, ceremony and evidence. It is not an HTTP request that lets the browser choose an actor,
return URL, or authentication result. A stale, superseded, wrong-browser, or replayed completion
must not create another session or bind a different actor.

The canonical Sign In policy remains authoritative after registration. A normal eligible
registration can feel like automatic login, but guardrails, MFA, checkpoints, selector rules,
cooldowns, and session limits still apply. If those rules reject the login or Visa cannot commit a
Root Session, the Identity remains registered and follows the normal Sign In recovery/refusal route.

User switching and system completion are different:

| Event                      | Required behavior                                                                 |
| -------------------------- | --------------------------------------------------------------------------------- |
| Initial-page user switch   | End the current flow through Visa and issue a fresh Admission for the other flow. |
| Switch after progress      | Refuse without cancelling another flow or changing a Session.                     |
| Durable Sign Up completion | Enter ordinary Sign In admission through an operation-bound handoff.              |

`prompt=login` fixes user entry to Sign In; `prompt=create` fixes it to App/Com Sign Up; unqualified
prompt starts with Sign In and permits only the initial-page switch; `prompt=none` starts no UI or
ceremony. The `prompt=create` user-switch restriction does not suppress the system-originated
completed-registration handoff.

Before declaring a refactor compliant, exercise the App and Com registration methods, incomplete
registration, Sign In guardrails, session failure after durable registration, duplicate finalize,
replay, stale tabs, OIDC state/PKCE/nonce/issuer checks, and wrong-surface or wrong-actor results.
Distributed Base/Auth race coordination remains D14 and must not be described as atomic until it is
separately decided and verified.

See the [D13 ADR](../../adr/sign-in-first-and-sign-up-handoff.md),
[Sign Up sequence](sign-up-sequence.md), and [Sign In sequence](sign-in-sequence.md).
