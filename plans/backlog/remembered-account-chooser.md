# Remembered Account Chooser (Proposal)

**Status: PROPOSAL — NOT STARTED. Not accepted for implementation.** Recorded 2026-10-07.

This is future work captured so the design intent is not lost. Do not implement from this file. It
ranks below IdP core authentication, authorization, and RBAC work.

The design direction and its security properties are in
[`adr/remembered-account-projection-and-store-boundary.md`](../../adr/remembered-account-projection-and-store-boundary.md),
which is itself proposed and deferred. This file lists the work and the decisions that would have to
be made first.

## Goal

Let the sign-in screen list accounts previously used in the same browser, including after sign-out,
without giving that memory any authentication authority and without exposing the identity source of
truth to the account chooser.

## Direction carried from the ADR

- Remembered accounts and authentication sessions are separate concepts; sign-out does not have to
  clear remembered accounts.
- The browser holds one opaque random identifier in a long-lived cookie; the data is server-side.
- The data is an allow-listed snapshot copied at successful sign-in, not a cache of the identity
  source of truth.
- The store is a logically independent boundary behind a storage abstraction.
- Co-location in the token (`*_ticket`) database is a provisional physical placement only.

## Decisions required before implementation

Every item below is open. Entries marked "candidate" repeat an option from the ADR and are not
decided.

- [ ] **Threat model.** Cover cookie theft and tampering, store disclosure, shared and public
      devices, and an attacker with brief access to an unlocked browser.
- [ ] **Privacy, account enumeration, and tracking.** Assess what the chooser reveals to anyone who
      opens the sign-in screen on that browser, whether a long-lived browser identifier is a
      tracking identifier and what consent or notice it needs, and how the data is handled under
      erasure requests.
- [ ] **Remembered browser identifier format.** Length, entropy, encoding, rotation, and whether the
      stored form is the raw value or a digest.
- [ ] **Cookie policy.** Name, lifetime, `Secure`, `HttpOnly`, `SameSite`, `Path`, host scope, and
      `__Host-` prefix (candidates). Decide whether this is the `continuity` cookie reserved by
      `adr/preference-scope-and-browser-persistent-state-separation.md` or a separate cookie.
- [ ] **Owning origin.** Which origin sets the cookie and renders the chooser. A host-only cookie
      is readable by one host, so this follows from where sign-in entry lives under
      `adr/base-auth-ceremony-and-seven-rp-boundary.md`.
- [ ] **Surface scope.** Whether the feature applies to `app`, `com`, and `org` or a subset, with
      remembered state kept inside each surface. The org surface signs in through Microsoft Entra
      ID (`adr/org-entra-id-sign-in-boundary.md`), which may make the feature inapplicable there.
- [ ] **Snapshot schema.** The attribute allow-list, the form of the opaque subject reference, the
      masking rule for the login identifier, the avatar reference form, and version metadata.
      Candidate attributes are listed in the ADR.
- [ ] **Retention and expiry.** Per-snapshot and per-browser lifetimes, the maximum number of
      remembered accounts per browser, and the cleanup job. Reconcile the candidate expiry
      timestamp with the two retention columns fixed by
      `adr/retention-lifecycle-column-boundary.md`.
- [ ] **Forget-one-account and forget-browser experience.** Where the controls live, whether they
      are available while signed out, and what confirmation they need.
- [ ] **Sign-out interaction.** Whether sign-out offers to forget the account, and what each logout
      path in `adr/logout-primitive-and-composition.md` does to remembered data.
- [ ] **Schema and database role separation inside the token database.** Separate PostgreSQL
      schema, separate role, or naming convention only; and how joins and foreign keys to token
      tables are prevented in practice.
- [ ] **Storage abstraction.** The interface of the store (called `RememberedIdentityStore` in the
      ADR as an illustration), its placement under `project/value-object-boundaries.mdc`, and the
      guarantee that callers never depend on its physical database.
- [ ] **Copy boundary from the identity source of truth to the snapshot.** The single place in the
      sign-in completion path that writes the snapshot, how the allow-list is enforced there, and
      what a snapshot write failure does to sign-in.
- [ ] **Disabled, deleted, and locked accounts.** Whether their snapshots are removed, hidden, or
      left to expire, and how that is done without the chooser reading the identity source of
      truth. Include credential change, account recovery, and administrative enforcement.
- [ ] **Staleness.** Whether a later sign-in refreshes the snapshot, and whether profile changes
      made elsewhere are ever propagated.
- [ ] **Criteria for physical database separation.** The conditions (for example data volume,
      access-role requirements, incident blast radius, or compliance scope) that move the store to
      a dedicated database, and the migration approach.

## Milestones (not scheduled)

1. Threat model and privacy assessment; decide whether to proceed.
2. Resolve the decisions above and promote the ADR from proposed to accepted, revising it where the
   decisions differ from the recorded direction.
3. Storage abstraction and provisional tables in the token database.
4. Snapshot write at sign-in completion.
5. Account chooser, forget-one-account, and forget-browser.
6. Expiry cleanup and operational documentation.
7. Physical database separation, when the agreed criteria are met.

## Out of scope for this record

Any migration, schema, route, cookie, front-end, or authentication-flow change.
