# URL, Path, Redirect and Upload Security Follow-ups

**Status: Deferred; no runtime changes authorized by this backlog entry.**

## Review outcome and limits

The 2026-10-22 investigation did not identify a confirmed user-controlled exploit path for SSRF,
path traversal, open redirect or unsafe file upload in the inspected application paths. This is a
bounded review outcome, not proof that vulnerabilities are absent.

The review covered application HTTP adapters, redirect resolvers and callers, file delivery,
Shrine uploaders, attachment assignment entry points and relevant existing tests. Related Rails
tests could not execute because test database preparation failed with `PG::DuplicateTable` for
`publishing_media_files`. No requests to internal hosts or cloud metadata endpoints were sent;
actual DNS, network egress, metadata access and deployed gateway behavior remain unverified.

These follow-ups are deferred at the user's request. Record a new verification result against the
revision actually examined when work resumes; do not treat the earlier review as release approval.

## Outbound destination restrictions

`app/lib/outbound_http/connection.rb` enforces HTTPS when requested and does not install redirect
following. It does not reject local/private destination IPs or validate DNS results. Offline
connection construction accepted HTTPS URLs for localhost, IPv4/IPv6 loopback, RFC1918, IPv6 ULA
and link-local addresses, `169.254.169.254` and `metadata.google.internal`. Construction acceptance
does not establish successful transport or metadata retrieval. Plain HTTP metadata was rejected
when HTTPS was required.

No inspected request input selected an arbitrary outbound host; destinations came from fixed
provider endpoints, application configuration or static client registration. Consequently this is
a defense-in-depth gap, not a confirmed exploitable SSRF finding.

When selected for implementation:

- Inventory endpoint ownership and legitimate internal service connections before choosing
  per-client destination policies; preserve required internal application traffic.
- Assess exact endpoint allowlists and deployment egress restrictions, including IPv4/IPv6,
  DNS changes/rebinding and cloud metadata access. HTTPS alone does not restrict destination IPs.
- Verify that credentials cannot be forwarded to an unauthorized origin and that redirects remain
  unfollowed. Use controlled destinations and avoid retrieving real metadata credentials.

## Required Jump/Away policy enforcement

The accepted [gateway selection policy](../../docs/security/redirect_targets.md#required-gateway-selection)
requires Jump for approved subdomain changes within the same application domain and Away for
cross-TLD navigation, including first-party destinations. The policy amendment is documentation
only. Existing direct `allow_other_host: true` callers and the single-Jump-gateway implementation
have not been migrated; these are contract/enforcement gaps rather than demonstrated open redirects.

When selected for implementation:

- Inventory cross-origin links, redirect responses and browser navigation targets, including
  existing direct handoffs; classify the final destination rather than the gateway hop.
- Centralize gateway selection and exact HTTPS origin validation. Preserve destination
  authorization, approved Jump edges and receiver-owned protocol/security checks.
- Define Away's authorization, token and receiver contract before integrating it. Unsupported
  routes must fail closed without direct or Jump fallback. Review method-preserving POST and
  server-to-server contracts separately.
- Update enforcement tests and implementation documentation together. Continue the existing
  [Away integration work](xt-away-external-navigation-gateway.md) rather than creating a competing
  gateway design.

## Deferred verification

- Resolve the test database preparation problem in a separately scoped environment task without
  destructive repair as part of this security backlog. Rerun the blocked HTTP, redirect and
  uploader tests and the relevant attachment tests.
- Preserve the observed resolver checks: 13 unsafe inputs rejected and three local paths accepted
  in a standalone run. These checks do not substitute for controller or gateway integration tests.
- Assess upload coverage for exact size boundaries, spoofed MIME/filename combinations, active
  content and forged cached attachment metadata through reachable public interfaces. Existing
  tests cover valid PNG, non-image rejection, oversize rejection and filename-independent keys;
  the review did not execute these Rails tests or demonstrate an upload exploit. Reconfirm the
  current absence of public file/attachment-metadata assignment paths before expanding that API.

## Completion criteria

Record the chosen destination policies and their evidence, reconcile gateway callers with the
accepted contract, and complete risk-appropriate public-interface verification. Report remaining
unverified deployment properties explicitly; backlog closure requires results, not documentation
of intended protections alone.
