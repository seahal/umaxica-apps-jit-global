# Global browser region canonicalization

Status: verified

## Purpose and authority

On 2026-10-25 the owner requested automatic insertion of `ri` when Global browser URLs omit it.
This supersedes the Base Home/Dashboard in-place-only region exception and Visa public-root
region exemption. Reuse `PreferenceGlobal#set_region`, not a second redirect implementation.

## Scope

Global browser HTML navigation: Base, Auth and Visa APP/COM/ORG, plus the already participating
Tech/ORG and Edit/ORG surfaces. Base's Home/Dashboard HTML exception is removed; its JSON in-request context is preserved. Visa roots explicitly
include the existing request-context concern and register its region callback on their own bare
boundary; they do not hydrate preference state or issue cookies. Auth/Tech/Edit retain their
existing callback pipeline. Core/Palm/Warp regional behavior and Publishing content are outside
this change, as are protocol, JSON, metadata and health endpoints with existing exemptions.

## Acceptance

- AC-1: Missing region on GET/HEAD canonicalizes to the same origin and path with the existing
  resolved region (default `jp`), preserving valid supplied query context.
- AC-2: Valid `jp` and `us` render without a redirect loop. Missing, blank, unknown and reachable
  malformed region values follow the existing shared normalization contract.
- AC-3: Base Home/Dashboard retain their final authentication/authorization outcomes after region
  canonicalization. Visa roots remain passive and issue no cookies on redirect or render.
- AC-4: Visa public protocols retain their original paths/parameters and remain outside the root
  canonicalization callback. Existing CSRF, host, rate-limit and authentication boundaries hold.
- AC-5: Request tests and Chromium confirm Global root canonicalization; affected ADRs and region
  guards describe the new contract. Existing unrelated work and unwaived cycle gates stay intact.

## Verification

AC-1 through AC-5 are verified for this scope in
`evidence/2026-10-25-global-region-canonicalization-R1G8.md`: 152 tests/2,416 assertions and
Chromium checks on all nine Base/Auth/Visa realm hosts pass. The Global root GET/HEAD matrix also
covers Tech and Edit. This is local verification; the full suite and deployment remain separate.
