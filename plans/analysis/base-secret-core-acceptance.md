# Base, app Secret, and Core acceptance catalog

Recorded: 2026-10-03 (UTC). This catalog defines required observations; it reports
no runtime test results. Use it with the
[integration analysis](base-secret-core-integration.md) and
[contract precedence ADR](../../adr/base-secret-core-contract-precedence.md).

## Evidence and result semantics

- **PASS:** the named claim is supported by results from the reported checkout and
  test scope. Code reachability, integration success, browser completion, and deployed
  behavior are separate claims.
- **FAIL:** an executed check contradicts its accepted expectation. Identify existing
  versus newly introduced failures.
- **NOT_RUN:** not executed; explain missing environment, time, checkout, or other input.
- **BLOCKED:** a named contract, authorization, or prerequisite is unresolved. Record
  evidence, dependent changes, smallest options, recommendation, and required decision.
- **NOT_APPLICABLE:** the boundary demonstrably does not apply; include the reason.

A document, route, enqueue, mock success, or earlier session's result is not proof
of completed behavior. No result begins as PASS. Record repository/branch/full HEAD,
relevant dirty state, timezone, commands, exit outcomes, and exact verification scope.
CI results additionally identify SHA, workflow, and trigger. Never retain raw secrets.

## Base: independently verify app, com, and org

| ID | Required observation |
| --- | --- |
| B1 | Anonymous HTML Dashboard reaches same-Base `/sign` through the gate before business-resource access; no admission or session is issued by this GET. |
| B2 | Public Home and existing authenticated Home rejection remain intact. Authenticated Dashboard displays or follows its existing selector/authorization contract. |
| B3 | GET `/sign` is passive, including authenticated display. Authenticated new POST starts terminate without logout, session replacement, or compensating redirect. |
| B4 | Authorized CSRF-valid POST starts once; admission, signed Jump, Auth ceremony, Base result validation, canonical session commit, and permitted destination are verified end to end. |
| B5 | HTML, actual-version Inertia, JSON/API, and HEAD follow their distinct adapters. API does not receive login HTML; HEAD has no body or ceremony start. Headers cannot bypass authentication. Check protected non-document requests. |
| B6 | Privilege denial, hidden resources, restricted sessions, invalid references, and infrastructure/configuration errors remain distinct from ordinary anonymity. Valkey/key failures do not cause bypass or false login. |
| B7 | Validate and consume returns through session updates, cancellation, expiry, multiple tabs, old references, and back navigation. Distinguish default Dashboard success from original-fullpath restoration. |
| B8 | Local malicious-return and Jump tests reject external/scheme-relative/userinfo/backslash/control/encoded separators, malformed/duplicate/structured query, cross-surface paths, wrong purpose/source/destination, expiry, tampering, and replay without redirecting to an unverified target. |

Use actual routes, FQDNs, callbacks, and signed URL primitives. A first Location or
stubbed gate/validator/signature chain does not satisfy B4 or B8.

## Secret persistence, capacity, and enrollment

| ID | Required observation |
| --- | --- |
| S1 | app-only rebuild enforces Client NOT NULL/FK ownership, unique public/lookup identifiers, lifecycle constraints, and immutable credential identity/value/terminal facts. Old kind/status/counter and app Emergency dependencies are removed. |
| S2 | Both registration contexts exercise A=0..20, explicitly 0,1,2,17,18,19,20. A=1 adds two to reach three; A=19 offers one with limit reason. |
| S3 | A=20 is normal omission: zero RNG/candidates/plaintext payload/reservation/new-value confirmation. Notice is inline/I18n; Passkey registration may complete. Retrying that registration after capacity changes does not create a new batch. |
| S4 | A excludes pending/claimed/terminal credentials; R counts live reservations separately. A=18/R=2 is a competing issuance, not a claim of 20 valid Secrets. Account suspension does not release credential capacity. |
| S5 | Separate writer connections and barriers reproduce issuance at 18/19/20, manual versus registration issuance, confirmation versus deletion/claim/expiry, and simultaneous claim. Fixed lock order preserves A<=20 and A+R<=20 without partial confirmation or deadlock caused by inconsistent order. |
| S6 | One pending issuance per Client: same authorized operation retries converge; another operation conflicts and cannot obtain the first session's candidates. Expired reservation stops counting with jobs stopped; late confirmation still fails. |
| S7 | Two candidates confirm atomically as the fixed presented set. Before confirmation they cannot authenticate; pending enrollment cannot normally sign in. Interruption preserves Passkey-saved/delivery-pending facts without duplicate registration. |
| S8 | Normal consumption/deletion to one or zero causes no replenishment, low-count notice, forced flow, or Passkey denial. Manual addition is one; no automatic replacement at capacity. Last-authenticator protection remains a separate policy. |

## Secret authorization and delivery

| ID | Required observation |
| --- | --- |
| S9 | List/detail require normal authentication, ownership, and current account authorization. Addition, rename, deletion, presentation, and confirmation recheck the operation's current Step-Up requirement. |
| S10 | Wrong owner, absent/expired proof, wrong method/scope/session/transaction, logout, and invalid CSRF cannot mutate or reveal. Signed-in bootstrap cannot bypass these checks. Initial enrollment authorization cannot authorize a later signed-in operation. |
| S11 | Newly registering a Passkey does not authorize itself. Secret cannot satisfy Step-Up/recovery; a normal Secret-derived session can Step-Up through another currently allowed method. |
| S12 | GET/HEAD/OPTIONS, prefetch, reload, and redraw do not generate, consume, or replace candidates. Explicit protected presentation uses short-lived encrypted server payload. |
| S13 | Missing/expired/undecryptable payload, wrong operation, unpresented confirmation, duplicate request, response loss, and cancellation cannot confirm unseen fallback values. Explicit reissue invalidates the prior pending set and reservation; confirmed values are never restored. |
| S14 | Real browser history/back/restore, Inertia history, Service Worker/cache, storage, URLs/Referer, cookies, logs, telemetry, and Chronicle do not expose plaintext or delivery bearer. no-store alone is insufficient evidence. |

Saving is a user's storage declaration. It is neither authentication proof nor a
Step-Up success. A response written by the server does not prove receipt by the user.

## Secret Sign in, audit, and reclamation

| ID | Required observation |
| --- | --- |
| S15 | Canonical Auth app GET/POST `/sign/in/secret` works; app Emergency entry is withdrawn and org Emergency retained. Guest, CSRF, region, legitimate handoff, Turnstile and online limits remain effective. |
| S16 | Every eligible Secret can authenticate regardless of issuance order. Full-value indexed lookup and complete verification resolve Client without public_id or hidden verified-contact requirements. Unknown input does not lock unrelated credentials. |
| S17 | Concurrent submissions have at most one irreversible Zenith claim. Bind Client, credential, trusted operation, and browser flow; arbitrary operation IDs or Ruby object types do not authorize. |
| S18 | Canonical login alone commits sessions/tokens and durable receipt. Ticket rollback, session-limit waiting, terminal rejection, cancellation/expiry, post-commit failure, delayed callback, and response loss cannot restore Secret or establish a second root login. Same-operation reconciliation uses persisted evidence. |
| S19 | Consumption does not revoke the newly issued session; derived RP sessions follow existing rules. Failed terminal claims retire safely, while unknown/live claims retain reconciliation evidence. |
| S20 | Mutation and source outbox rollback/commit together. Chronicle outage, enqueue failure, duplicate delivery, and crash after Chronicle commit recover through scanning and event-ID deduplication. Recorded, enqueued, and Chronicle-delivered are distinct. |
| S21 | Terminal credentials are unusable with jobs stopped. Earlier terminal audit must reach Chronicle before physical deletion. Delete and surviving purge outbox commit together; purge delivery follows deletion without circular waiting or cascade loss. |
| S22 | One app deletion owner preserves legal holds/kill switches. Candidate/payload/reservation/claim/receipt/outbox cleanup respects continuation and delivery. Missing audit policy/event configuration is explicit, not request-time creation or log fallback. |
| S23 | Disposable fresh build and old-app-schema rebuild both succeed without touching unrelated Client/credential/history or com/org state. Record DDL creation separately from application; discarded old data is not rollback-recoverable. |

Test 31/32/33-character inputs and reachable missing, nil/null, empty, zero,
array/object, NUL, and invalid alphabet inputs; frontend undefined is distinct from
Ruby nil. At each defined limit/expiry test immediately before, equal, and after,
using the actual owning clock. Apply existing name/return limits similarly. Do not
use Emergency duration as a new Secret expiry default.

## Core and conditional continuation

| ID | Required observation |
| --- | --- |
| C1 | Common SSR makes no user-specific Rails call; initial HTML/hydration agree on checking state. Browser alone uses configured public Rails-owned paths. No server function, middleware, loader, VPC, or fallback proxies to Rails. |
| C2 | Ordinary TanStack sees no Cookie and cannot emit authentication Set-Cookie; Rails responses retain required cookie attributes and multiple Set-Cookie values for the next browser request. No token enters JavaScript, SSR props, query cache, or browser storage. |
| C3 | Exact scheme/host/effective-port pairs and fixed-version CSRF/Fetch Metadata handle same-origin, sibling host, cross-site, missing/null/invalid Origin, port/scheme mismatch, and contradictory metadata. Rejection precedes mutation; narrow legitimate callbacks/logout still work. |
| C4 | Checking, available, confirmed reauthentication-required, and temporary failure remain distinct. HTML/redirect API errors, 403/429/5xx, and transport failures do not trigger blanket logout, refresh, write retry, or infinite loops. |
| C5 | Logout/subject switch/reauthentication discard old responses even if abort fails. Other-user/org/surface/region access is denied by Rails. Synthetic rendering/logging sentinels do not execute or disclose credentials. |
| C6 | Personalized dynamic responses avoid shared cache. Fingerprinted assets alone may use cache. Rails and Workers limits remain independent; Rails shared counters remain effective across instances. No invented thresholds or silent infrastructure fallback. |
| C7 | Misrouted Rails requests fail closed in the target configuration. Dispatcher removal and actual routing cutover remain separately evidenced and cannot accidentally disrupt an existing deployed entrance. |
| R1 | With valid access, no unnecessary rotation; with only access expired/missing and valid continuation, the actual approved browser path is tested. Confirm credential cleanup distinguishes this from proven-invalid credentials. |
| R2 | Verify parent/RP continuity, simultaneous refresh, replay, response loss/order, and logout races without extending absolute lifetime or Step-Up freshness. DB/signature outages remain distinct from invalid credentials. |
| R3 | If new GET mutation, endpoint, rotation/retry/grace/storage, or access-only semantics are necessary, dependent change is BLOCKED. Reproduction is not made green through a skip or an unapproved protocol. |

External CloudFront/routing evidence must separately cover zero cache TTL behavior,
required forwarded cookies/source/protocol headers, redirects/errors, multiple
Set-Cookie, logging/sampling, and A/B/anonymous non-sharing. Local no-store does not
certify these deferred deployment controls.

## Completion report template

| Area | Initial result | Required evidence scope |
| --- | --- | --- |
| Base authentication guidance | NOT_RUN | B1-B8 separately for app/com/org |
| app Secret persistence | NOT_RUN | S1, S23; ownership and DDL scope |
| Secret issuance/management | NOT_RUN | S4-S14; authorization and real concurrency |
| Secret Passkey 2/1/0 | NOT_RUN | S2-S8 in both registration contexts |
| Secret Sign in/atomic claim | NOT_RUN | S15-S19; durable cross-DB reconciliation |
| Secret audit/purge | NOT_RUN | S20-S22; delivery and deletion fault cases |
| Core browser/Rails boundary | NOT_RUN | C1-C2, C7; separate Rails/Edge checkouts |
| Core security boundary | NOT_RUN | C3-C6; real-browser and server observations |
| Login continuation/refresh | NOT_RUN | R1-R3; accepted-contract or explicit blocker |
| app/com/org regression | NOT_RUN | Existing authentication/Jump/session and unchanged com/org Secret suites |
| Deployment readiness | NOT_RUN | Deferred external routing/cache/configuration gates |

For each actual result, cite commands and evidence, list unexecuted cases and their
reasons, and identify residual risks. Report overall application boundary, login
continuation, and deployment readiness separately. Documentation completion never
turns this template into an implementation success report.
