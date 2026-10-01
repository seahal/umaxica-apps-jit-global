# Xper Phase 1 Activation Gate

This gate follows the [Xper Phase 0 decision](../../adr/xper-phase-zero-bootstrap.md).
Phase 0 route and request tests do not establish private DNS, Tunnel, Access, public DNS,
or public apex reachability. The network alias change takes effect only after rebuild.

Run this sequence before starting Experience API implementation:

1. Apply the reviewed Compose alias change if Phase 0 recorded it as blocked, then rebuild
   the devcontainer. Confirm `core` has Xper and Warp app/com/org aliases on `frontend`.
2. Boot Rails through the established development entrypoint.
3. Prepare and seed the development database through the repository workflow.
4. Confirm `fqdn_available_xper_service`, `fqdn_available_xper_corporate`, and
   `fqdn_available_xper_staff` are enabled. Development seed uses
   `FqdnAvailabilityRegistry.flag_names`; production requires explicit operator action.
5. Verify private DNS resolution for `xper.{app,com,org}.localhost` and
   `warp.{app,com,org}.localhost` from the Tunnel's network.
6. Verify private HTTP routing on port 3000 with the corresponding public `Host` header.
   Xper public hosts are `umaxica.{app,com,org}`; Warp hosts are `www-jp.umaxica.{app,com,org}`.
7. Verify Cloudflare Tunnel service targets, Host preservation, and the existing Access boundary.
8. Verify all three public apex homepages resolve to their independent Xper landing pages.
9. Verify health, revision, CSP intake, robots, and sitemap through their intended paths.
   Preserve the existing edge isolation of operational endpoints; public blocking is expected
   where that policy applies. Check private SEO responses still name only the public canonical
   authority and that homepages issue no Preference or Experience credential cookie.
10. Record actual results in `evidence/`. Begin Experience API work only after this gate passes.

Do not enable production availability automatically, weaken Host Authorization, move Preference
state, or introduce API/cache/Service Worker behavior to get this gate to pass.
