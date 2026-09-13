# Identity / Account / Organization / Avatar

Core SNS-domain ubiquitous language for the authentication subject (Identity), the service-usage
subject (Account), the organizational/billing unit (Organization), and the SNS-facing embodiment
(Avatar).

These terms follow the accepted `adr/surface-account-collective-model-naming.md` and
`adr/identity-authority-boundary.md`. Each term carries a short Japanese gloss under the
repository-language exception for dictionary definitions; all other prose is English.

---

### Identity

- Definition: The authentication subject — the runtime actor that owns credentials and sessions and
  performs login. Implemented per surface as `Client` (app), `Operator` (org), and `Visitor` (com).

<!-- repository-language: allow-next-line reason=localized-gloss -->

- 和訳: ログイン・認証の主体（runtime actor）。資格情報とセッションを保持する。
- Context: `app`, `org`, `com`. Authentication, current-context, authorization, and token
  vocabulary.
- Notes:
  - Owns: credentials, sessions/tokens, `login_allowed?`, withdrawal lifecycle.
  - Does not own: display name, Avatar, Organization membership, billing.
  - `ClientIdentity` / `OperatorIdentity` / `VisitorIdentity` are **Identity binding** records
    (IdP/RP boundary), not the runtime actor and not the Account.
  - Bound to exactly one Account for now (1:1; see Account). A future phase may allow 1→N.
  - Forbidden aliases: do not use `User`, `Staff`, or `Customer` as the actor name; do not conflate
    `*Identity` binding records with Account.
- Status: accepted.

### Account

- Definition: The service-usage subject, bound to one Identity. It is a member of one or more
  Organizations and operates Avatars (app/org only). Canonical models: `Persona` (app), `Agent`
  (org), `Individual` (com), each including the `Account` concern.

<!-- repository-language: allow-next-line reason=localized-gloss -->

- 和訳: サービス利用の主体。Identity に紐づき、Organization に所属し、Avatar を操作する（app/org のみ）。
- Context: `app`, `org`, `com` (zenith realm).
- Notes:
  - Owns: mutable moniker (history-tracked), Organization membership, Avatar operation rights
    (app/org).
  - Does not own: credentials/sessions (Identity), billing (Organization).
  - Must belong to at least one Organization (including solo natural-person accounts).
  - Transitional models being migrated into the canonical Account: `Member` (app_principal),
    `OperatorWorkspaceAccount` (org_zenith).
  - `ClientAccount` / `OperatorAccount` / `VisitorAccount` are OIDC RP account records and are
    **not** this Account.
  - Forbidden aliases: do not use `User`, `Stakeholder`, or `Member` as the canonical term.
- Status: accepted (naming); migration in progress.

### Organization

- Definition: The hierarchical organizational unit and the billing unit (the Collective). Canonical
  models: `Enterprise` (app), `Bureau` (org), `Company` (com), each including the `Collective`
  concern, with hierarchical `*Unit` nodes (`EnterpriseUnit` / `BureauUnit` / `CompanyUnit`) backed
  by closure tables (`parent_id` immutable).

<!-- repository-language: allow-next-line reason=localized-gloss -->

- 和訳: 階層的な組織単位かつ課金単位（＝Collective）。ソロ個人も 1 つ持つ。
- Context: `app`, `org`, `com` (zenith realm). For `com` the Organization (`Company`) is internal
  only and is not exposed in UI/API entrypoints.
- Notes:
  - Owns: hierarchy (Units), billing, contracts, Avatar ownership (app/org), mutable name
    (history-tracked).
  - Does not own: credentials, Avatar operation execution (done via Account).
  - Billing is scoped to the Organization, never directly to an Account.
  - Transitional models being migrated into the canonical Organization: `Organization` / `Division`
    / `Department` (org_principal).
  - Forbidden aliases: the ubiquitous/UI term is "Organization". `Workspace` survives only as a
    transitional org_principal implementation name. Do not use `Tenant`. `Collective` is a concern
    name, not a domain term.
- Status: accepted (naming); migration in progress.

### Avatar

- Definition: The SNS-facing embodiment, operated by one or more Accounts (`Persona` / `Agent`). It
  is an **app/org capability only — `com` (Visitor / Individual) cannot use Avatars.** It may be an
  Organization-owned asset. It has a mutable moniker and a mutable handle.

<!-- repository-language: allow-next-line reason=localized-gloss -->

- 和訳: SNS 表出体。1 つ以上の Account が操作。app/org のみ、com 不可。
- Context: `app`, `org`.
- Notes:
  - Owns: moniker (`avatar_monikers`, history-tracked), handle (`handle_assignments`,
    history-tracked), follow/block/mute, and (future) posts.
  - Does not own: credentials, billing, login.
  - Operation is recorded on `avatar_memberships` (the Avatar operator join), which references the
    operating Account via mutually-exclusive `persona_id` / `agent_id` columns.
  - Ownership (Organization asset) is recorded on `avatar_ownership_periods`.
  - Forbidden aliases: do not use `Profile`, `Persona`, or `Character` as the canonical term
    (`Persona` is the app Account implementation, a different concept).
- Status: accepted (naming); migration in progress.

### Handle

- Definition: An Avatar's mutable, user-visible identifier, displayed with a leading `@` and stored
  canonically without `@`. Unique among non-system handles.

<!-- repository-language: allow-next-line reason=localized-gloss -->

- 和訳: Avatar の可変識別子。`@` 付きで表示し、`@` なしで保存する。
- Context: `app`, `org` (Avatar domain).
- Notes:
  - Stored without `@`; rendered/edited as `@handle`.
  - Uniqueness: enforced for non-system handles via a partial unique index
    (`uniq_handles_handle_non_system`) and model validation; system handles are exempt.
  - Handle changes are history-tracked via `handle_assignments`.
  - Related models: `Handle`, `HandleAssignment`, `HandleStatus`.
- Status: accepted.

### public_id

- Definition: The immutable, externally-exposed identifier for a core entity. Internal `id` (the DB
  primary key) is never exposed externally. NanoID-21 by default, globally unique by DB constraint,
  immutable for Identity / Account / Organization / Avatar.

<!-- repository-language: allow-next-line reason=localized-gloss -->

- 和訳: 外部公開用の不変識別子。内部 `id` は外部に出さない。
- Context: all surfaces.
- Notes:
  - Generated by the `PublicId` concern on create; immutability is enforced by an update guard.
  - Do not expose internal `id` in URLs, APIs, serializers, or form fields; address records by
    `public_id`.
  - Exception: `Operator.public_id` is currently a 16-char BASE32 value (not NanoID); unification is
    deferred.
- Status: accepted.
