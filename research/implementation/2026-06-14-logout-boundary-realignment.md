# Logout Boundary Realignment

The logout active plan from 2026-06-05 still contained Sign-owned logout mutation wording. The
current accepted component boundary is the 2026-06-12 Acme/Sign/Core/Base/Port model:

- Acme remains the logout and session-token authority in the current Rails implementation.
- Sign is a special relying party and must not become the durable logout mutation owner.
- Sign may host a state-free `/signed-out` guest page that does not authenticate, revoke tokens,
  reset Rails session state, consume flash, or write audit.

This implementation slice keeps Acme `/sign/out` as the mutating logout path and redirects
successful ordinary logout completion to the matching Sign `/signed-out` page.
