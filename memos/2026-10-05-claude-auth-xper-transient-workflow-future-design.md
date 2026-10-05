# Auth / Xper Transient Workflow Future Design Discussion

Discussion date supplied by the user: 2026-10-05

Status: Discussion record; not authorized for implementation in the current cycle.

Scope: Documentation only. This memo records a design discussion for a future Auth and Xper workflow
redesign. It changes no implementation in the current Base/RP consolidation cycle and is not a
source of truth.

## Current-cycle freeze

This cycle must not refactor, replace, or add Auth or Xper workflow code on the basis of this memo.
In particular, their routes, cookie lifecycle, Valkey transport, capability format, and ceremony or
Experience implementation must not change merely to share code with the RP work.

The RP/Base redesign must likewise not treat legacy Auth or Xper implementation details as the
canonical RP pattern.

## Stable boundaries

- Base remains the sole OIDC OpenID Provider and OAuth Authorization Server.
- Auth is not an OIDC RP, OP, or OAuth AS. It remains an authentication ceremony service.
- Xper is not an OIDC RP, OP, or OAuth AS. It is planned as an Experience workflow service.
- Auth public origins under `auth.*` are treated as stable external contracts. Historical Sign,
  Acme, or Apex naming must not drive another public hostname rename. Passkey and social-login
  origin and callback contracts are a primary reason for this stability requirement.
- Xper remains on the `umaxica.app`, `umaxica.com`, and `umaxica.org` apex origins. This carries
  DNS/CNAME operational constraints, but was chosen to limit further growth of Base's
  responsibility while replacing the failing Preference architecture with Experience.

The first three are already recorded as accepted decisions in
`adr/base-auth-ceremony-and-seven-rp-boundary.md`,
`adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md`, and
`adr/xper-phase-zero-bootstrap.md`, which also records the Xper apex origins.

## Transient-capability direction discussed

A future redesign may use short-lived opaque one-time capabilities inspired by OAuth
authorization-code semantics, without making Auth or Xper OAuth clients or authorization servers.

Common properties discussed:

- a high-entropy opaque raw capability;
- the raw capability is not persisted server-side;
- digest-keyed server-side state;
- explicit purpose, consumer or surface, Browser Session, and transaction binding;
- short TTL;
- one-time or generation-bound use;
- fail-closed behavior when authoritative transient state is unavailable;
- no silent fallback into another workflow;
- capability values are not carried in URL query strings or fragments;
- POST-body handoff is preferred where a browser crossing is required.

The current Auth implementation already uses a Valkey-backed opaque admission and result transport
with SHA-256 digest keys, a 60-second TTL, and atomic consume behavior. That implementation is
evidence for this discussion, not a commitment that a future shared primitive preserves its API.

## Browser Session scoped workflow idea

The discussion identified a possible future invariant:

```text
Identity -> Browser Session -> { Auth workflow 0..1, Xper workflow 0..1 }
```

A newer workflow may supersede an older workflow for the same Browser Session and workflow family.
A generation or current-slot model was preferred over retaining unbounded durable token-use
history. Expired and superseded Valkey records may disappear naturally by TTL.

Candidate absolute workflow lifetimes:

- Auth ceremony workflow: about 5 minutes.
- Xper Experience workflow: about 30 minutes.

These are candidates, not current normative configuration. Admission and result capabilities should
stay much shorter lived than the workflow session.

## Auth two-step shape

Auth fits a mandatory two-step design:

1. Base grants a one-time admission capability to begin a specific authentication ceremony.
2. Auth completes the ceremony and returns a separate one-time result capability to Base.
3. Base validates the matching authoritative transaction and performs the final Identity, Browser
   Session, and RP authorization state transitions.

Auth does not become the authority for durable login state.

## Xper difference

Xper may not ultimately require a mandatory return-to-Base step after every Experience operation.
Its final authority and persistence model are still fluid. The same admission and result shape may
be used as a conservative starting point, but the result handoff must not be frozen as a permanent
requirement until Experience authority is designed.

## Valkey direction

Transient capability and active-workflow state is a natural Valkey responsibility, because
retaining every used capability in PostgreSQL would grow without durable value. Meaningful security
and audit events may be retained separately; raw capability-use history should not be retained
merely for replay prevention.

Current nonproduction auth-state allocation is development logical DB 5 and test logical DB 6.
Namespaces prevent key-family collisions. A future Auth/Xper redesign should preserve explicit
separate namespaces even if both share the auth-state Valkey responsibility.

## Observed in the repository

Read while saving this memo, at commit `e8f2371bc5cbefd2087c728aeeef4e318463d33f`:

- `Valkey::AuthState::OpaqueAdmissionStore` keys SHA-256 digests only, uses a 60-second TTL and
  32-byte codes, and consumes through a Lua script that moves `issued` to `consumed` in place. It
  binds `actor_type`, `surface`, `subject_ref`, `base_session_ref`, and `ceremony_session_ref`, and
  distinguishes `missing`, `replay`, and `binding_mismatch` results.
- `config/valkey.yml` assigns `auth_state` to logical DB 5 in development and DB 6 in test.
- Xper Phase 0 has no credential lifecycle, so nothing in Xper corresponds to this discussion yet.

The candidate lifetimes, the Browser Session workflow invariant, and the generation or current-slot
model were not checked against code; they are proposals.

## Open Questions

- Whether Xper needs a return-to-Base result step at all once Experience authority is designed.
- Whether Auth and Xper share one transient-capability primitive or keep separate ones.
- The supersession rule when a newer workflow replaces an older one for the same Browser Session.
- The final workflow lifetimes.

## Promotion Candidate

- Promoted on 2026-10-05: the current-cycle freeze, the Auth public-origin stability requirement,
  and the Xper apex origins are now decided in `adr/defer-auth-xper-transient-workflow-redesign.md`.
  The deferred work is tracked in `plans/backlog/auth-xper-transient-workflow-redesign.md`.
- Still a candidate: the transient-capability properties and the Browser Session workflow invariant
  become an ADR when the redesign is authorized.
