# Identity / Persona / Organization / Avatar

This dictionary follows the accepted surface-local naming and authority decisions. Identity,
Persona, and Organization are distinct peer concepts. Persona and Organization are common Ruby
interfaces only; they are not shared Active Record models, tables, STI classes, or polymorphic
authority records.

## Identity

The authentication subject and runtime actor that owns credentials and sessions and performs login.
The concrete runtime principals are `Client` (`app`), `Visitor` (`com`), and `Operator` (`org`).

`ClientIdentity`, `VisitorIdentity`, and `OperatorIdentity` are RP/IdP binding records. They are not
RBAC principals, resource owners, or substitutes for the concrete principal foreign keys in
surface-local authority tables.

Identity suspension or termination changes the actor's authentication and effective permissions; it
does not silently suspend every resource owned by that principal. The coordinated ownership
resolution rules are defined separately in the authority implementation reference.

## Persona

The surface-local resource that an authenticated principal may use through explicit authority. The
common `Persona` name is a Ruby interface concern, not a persisted base model.

| Surface | Concrete implementation | Table         | Principal  |
| ------- | ----------------------- | ------------- | ---------- |
| `app`   | `ClientPersona`         | `personas`    | `Client`   |
| `com`   | `Individual`            | `individuals` | `Visitor`  |
| `org`   | `Agent`                 | `agents`      | `Operator` |

Each Persona has one current ownership row in its own surface. A resource owner has effective
administration, delegation, usage, and view authority without requiring automatically-created grant
rows. Non-owner Administration, Delegation, Usage, and View grants are independent capabilities; one
grant does not imply another. Usage is defined for Persona resources, not Organizations.

Persona ownership and grants do not create Organization membership, Unit, Position, Appointment, or
Avatar authority. Those relations remain separate contracts.

## Organization

The surface-local organization resource represented by the common `Organization` Ruby interface.

| Surface | Concrete implementation | Table         | Principal  |
| ------- | ----------------------- | ------------- | ---------- |
| `app`   | `Enterprise`            | `enterprises` | `Client`   |
| `com`   | `Company`               | `companies`   | `Visitor`  |
| `org`   | `Bureau`                | `bureaus`     | `Operator` |

Each Organization has one current ownership row in its own surface. Organizations do not receive
Persona Usage grants. Administration, Delegation, and View remain independent explicit grants.

`OperatorOrganization` is a legacy concrete org-principal model mapped to the existing
`organizations` table. It is not the common `Organization` interface and is not a replacement for
`Bureau` in the adopted authority model.

## Avatar

Avatar is the existing SNS-facing domain boundary. Avatar behavior, Avatar RBAC, lifecycle,
hierarchy, Position, and Persona–Organization membership are explicitly outside the current
Persona/Organization foundation work.

The existing `AvatarPersonaBinding` remains in the Avatar database and its `persona_id` relation is
resolved to `ClientPersona` after the concrete model rename. This mechanical mapping does not grant
authority, create a shared table, or change Avatar behavior. Do not infer new Persona ownership or
Organization authority from the legacy Avatar graph.

## Handle

An Avatar's mutable user-visible identifier, displayed with a leading `@` and stored without `@`.
The `@` allocation is Avatar-only. The current URL namespace policy is in
[`docs/reference/url-identifier-policy.md`](../reference/url-identifier-policy.md); it does not
create a new Avatar route in this work.

## `public_id`

An immutable externally exposed identifier. Internal database primary keys are not public URL or API
identifiers. Authority and transfer-request rows use concrete foreign keys internally; resource and
transfer-request public identifiers are used for external addressing where the contract requires
them. An opaque identifier is not an authorization credential.

## Related current references

- [`adr/surface-account-collective-model-naming.md`](../../adr/surface-account-collective-model-naming.md)
- [`docs/architecture/persona-organization-authority.md`](../architecture/persona-organization-authority.md)
- [`docs/reference/url-identifier-policy.md`](../reference/url-identifier-policy.md)
