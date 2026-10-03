# Browser verification procedures for Base, app Secret, and Core

Prepared on 2026-10-03 (UTC). These procedures have NOT_RUN status. They operationalize
the [acceptance catalog](base-secret-core-acceptance.md); they do not replace automated
tests or prove deployed behavior.

## Setup and recording

Use the repository's existing browser runner and a disposable local/test environment.
Record Rails and Edge checkout/HEAD/dirty state, browser version, timezone, public
origins and path ownership, and fixture identities. Use synthetic clients and test
keys only. Verify the target DB and suppress real mail/SMS or other external sending.
If setup is missing, record NOT_RUN rather than substituting another host or proxy.

Use independent browser contexts for users A/B and anonymous access, and two tabs
within one context for shared-session races. Prepare capacity fixtures through existing
authorized test support, not production SQL or frontend count overrides. Do not retain
HARs, screenshots, traces, logs, or storage exports containing plaintext credentials.
Inspect transient test data locally; retain only redacted summaries in flat evidence.

For each procedure record result, request method/path, response class, observed next
page, relevant nonsecret event/operation IDs, and remaining uncertainty. A browser
assertion about the UI cannot prove server row counts or durable receipts; correlate
those with the integration checks identified below.

## Base journeys

1. **Anonymous navigation (B1-B5):** in a clean context visit each actual app/com/org
   Base Dashboard. Observe same-Base Sign UI, no Dashboard business content, and no
   automatic start POST. Reload and navigate back/forward. Correlate with the server
   assertion that no admission/session was issued. Check public Home separately.
2. **Explicit start and completion (B4/B7):** activate Sign's existing form once.
   Observe the signed Jump route and corresponding Auth sign-in UI. Complete the
   existing test ceremony and required selection steps. Verify Base session and
   final permitted destination. Record default Dashboard and original-path return
   as separate outcomes; do not infer one from the other.
3. **Already authenticated (B2/B3):** visit GET `/sign` after completing login.
   Passive display is allowed. Attempt the form's new start through its ordinary
   supported UI. Confirm rejection and unchanged existing session, without automatic
   logout or compensating navigation. Server tests must also cover a direct POST
   even if the UI hides/disables that action.
4. **Cancel and independent tabs (B7):** start authorized flows in two tabs where
   supported. Cancel one; continue the other. Test back navigation and an old completion
   locator after success. Neither tab inherits the other's return destination or loops.

API/HEAD, malformed returns, and cryptographic tampering use local request/integration
tests. Do not send attack payloads to public production hosts. Inertia navigation
must use the actual client/version rather than synthetic headers alone.

## Secret issuance and management

5. **Distribution boundaries (S2/S3):** for both enrollment and signed-in Passkey
   registration, prepare A=0,1,18,19,20. Register a Passkey through the real UI.
   At 19 observe one value and its reason; at 20 observe omission and no reveal/save
   requirement. At 1 confirm two newly added credentials, not a total of two. Server
   tests cover every A=0..20 and prove zero generation/reservation/payload at 20.
6. **Presentation and history (S7/S12-S14):** enter pending issuance, reload before
   reveal, then explicitly reveal. Verify no earlier reveal request. Save through
   an explicit user action and confirm the whole set. Navigate back/forward, reload,
   restore the page, and inspect applicable Service Worker/cache paths. The original
   plaintext must not return from history, storage, or a server reveal. Inspect error
   reporting and URL/Referer handling with a synthetic sentinel, without exporting it.
7. **Lost reveal response (S13):** using supported local network controls, drop the
   response after the server processes reveal. Reopen the operation. A normal retry
   cannot silently supply new candidates; use only an explicitly supported reissue
   action that invalidates the pending batch. Confirm that no unseen value activates.
8. **Competing tabs (S4-S6):** begin issuance in one tab and another operation in the
   second. Observe an explicit conflict, not the 20-valid-item notice, and no foreign
   values. Let the reservation expire using approved test clock support. Late confirmation
   fails and a new authorized operation can use freed capacity. Real DB barriers,
   not browser timing alone, prove the capacity race invariant.
9. **Authorization changes (S9-S11):** open a management operation with valid Step-Up,
   then expire proof or log out in another tab. Reveal/confirm/rename/delete must fail
   on the next request. Try another user's public identifier locally. Registering a
   Passkey alone must not make an unauthorized management operation succeed.
10. **Interruption and ordinary depletion (S7/S8):** interrupt Secret delivery after
    Passkey persistence. Resume without registering another Passkey. Signed-in failure
    does not delete it; enrollment remains unfinished until confirmation or omission.
    Consume/delete down to one and zero with an available Passkey. Verify no count-based
    warning, replenishment, forced screen, or Passkey denial.

## Secret Sign in and Core continuity

11. **Single-use journey (S15-S19):** sign out and use an eligible confirmed Secret
    at canonical Auth app `/sign/in/secret`. Complete Base establishment and visit
    an allowed downstream surface. Attempt reuse from another context; it is refused.
    From the original normal session, perform a supported non-Secret Step-Up. The
    newly created session remains valid after consumption. Durable receipts and
    exactly-one claim/root login are verified in server concurrency tests.
12. **Failure after claim (S18):** use an existing test fault boundary to interrupt
    Ticket establishment or discard the completion response. Resume only through
    the same authorized flow. Observe the actual terminal/reconciliation UI; do not
    paste the Secret into a new flow to implement recovery. Correlate irreversible
    claim with the durable receipt and absence of a second root login.
13. **SSR and hydration (C1/C4):** request Core directly with JavaScript temporarily
    disabled; inspect common HTML without user data. Enable JavaScript and confirm
    initial hydration agrees with checking state. Observe Rails requests issued by
    the browser only. Worker execution tests separately establish absence of proxy calls.
14. **Access expiry and errors (C2-C4/R1-R3):** use supported test-time expiry with
    valid continuation credentials and observe actual browser behavior. No new refresh
    protocol is introduced for this procedure. Separately test confirmed session expiry,
    403, 429, 5xx, and network loss. Record continuity failure or BLOCKED honestly;
    temporary errors do not automatically log out or resubmit writes.
15. **Stale response (C5):** delay A's nonsecret personalized response, then log out
    or switch to B using an existing supported flow. Release the old response even
    if abort was attempted. It cannot overwrite B's current state, cache, or UI.
    Refresh and navigate back to check old-data reappearance.

## Deferred production observations

Local browser results cannot establish external routing, CloudFront zero-TTL/error
behavior, CDN credential logging, or independent deployed-browser non-sharing.
Those remain separate deployment gates with independent A/B/anonymous contexts.
This documentation task performs none of those external checks.
