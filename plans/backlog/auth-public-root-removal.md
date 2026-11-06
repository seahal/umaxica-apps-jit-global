# Remove the Auth APP and ORG Public Roots

Status: backlog. The owner decided on 2026-11-02 to defer this. Nothing below is started.

## Goal

`/` on the Auth APP and ORG hosts is unrouted and answers 404, as the Visa hosts already do. This
removes an anonymous landing page that no ceremony needs. It reduces the public surface but does not
close a known vulnerability.

## Why It Was Deferred

The root is also an internal redirect destination, so removing only the route sends users to a 404.
The change touches post-authentication redirects while the Auth tests are unreliable because of
committed test residue. Start after that residue is fixed.

## Known References

- `AuthenticationBase#default_after_login_path`.
  `AuthenticationRedirects#redirect_to_pt_destination!` forbids another host, so pointing the
  fallback at Base needs an explicit decision.
- `SignOrgNormalPasskeyCeremony` and `SignOrgStandbyPasskeyCeremony#passkey_default_redirect_url`
- `SocialAuth#social_auth_success_redirect_path`
- `Auth::Org::Sign::UpsController`, the cancel link
- `app/views/layouts/auth/{app,org}/application.html.erb`, the brand link
- `VerificationBase#actor_root_path`, which had no caller found and may be removable
- `Auth::{App,Org}::RootsController`, `src/pages/auth/{app,org}/roots/index.tsx`, and about 14 test
  files, listed by searching for `auth_app_root` and `auth_org_root`

Re-derive this list before starting; it reflects one search.

## Acceptance

- `/` on each Auth host answers 404 and issues no cookie.
- Each former caller reaches a working destination, verified through its public flow.
- No security check is relaxed to make a redirect work.
