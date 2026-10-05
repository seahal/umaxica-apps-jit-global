# Core browser API request boundary

Core app/com/org browser APIs verify unsafe requests before refresh or other action
processing. Each surface explicitly includes TrustedOriginForgeryProtection; the
existing CoreBrowserApiBoundary CSRF callback requires all of:

- an Origin accepted by the existing origin policy;
- a valid Rails session CSRF token in X-CSRF-Token;
- the fixed Rails header-or-legacy-token Fetch Metadata verification.

The API bases add no cross-origin trusted pair. A foreign host, different scheme or
port, malformed Origin, and Origin: null are refused. Missing Origin combined with
same-site metadata is refused rather than treating sibling hosts as same-origin.
A same-origin Origin combined with cross-site metadata is also refused. Missing
Fetch Metadata retains Rails' existing valid-token fallback; this change does not
require an Origin on every GET or introduce a new missing-header exemption.

GET, HEAD and OPTIONS keep their existing passive behavior. The explicit refresh
POST keeps its existing route, credential transport, rotation and failure contract.
This change adds no transparent GET renewal, browser timer, endpoint, retry window,
or response-loss recovery. General Rails protocol callbacks are unaffected.

Refusals use the existing 403 problem+json CSRF error contract. Tests cover all three
surface hosts and show that rejected requests do not change real RP refresh
credentials. This HTTP evidence does not establish Edge routing, browser Fetch
Metadata generation, or browser-driven access-expiry login continuity.

## Independent access and refresh refusal

A rejected RP access cookie still yields the existing 401 problem document,
deletes the unusable access cookie and returns no actor data. It does not delete
the independent RP refresh cookie. Session GET neither consumes that cookie nor
uses its presence to grant authority or rotate credentials. The previous pair
deletion rule is superseded in
[Invalid Browser Credential Recovery](../../adr/invalid-browser-credential-recovery.md).

The three-surface integration journey uses real signed expired access, malformed
access and persisted RP refresh credentials. With forgery protection enabled,
it verifies no RP mutation during refusal, then invokes the existing exact-Origin,
CSRF-protected POST. Rotation commits and the next session GET accepts the
Rails-issued access cookie. The RP public identity and authentication time are
preserved, and rotation does not extend the bounded root session's absolute expiry.

This proves the explicit Rails HTTP journey, not automatic browser continuation.
No new browser refresh call, timer, retry/grace protocol, storage mechanism or GET
renewal was introduced. Concurrent refresh, response loss, reversed responses and
the browser's choice of continuation path remain separate verification and design
gates. Retention of a refresh cookie is not proof that it is valid: the existing
POST still verifies the RP, parent session and account before rotation.

The framework behavior is grounded in the repository's bundled Rails revision
`2f75a03b05aff2610b3799ef9ebd87cfc9cf38eb`, in Action Controller's
`request_forgery_protection.rb` origin and header-or-legacy-token verification.
See [the execution record](../../evidence/2026-10-03-core-browser-origin-boundary-7P2A.md).
