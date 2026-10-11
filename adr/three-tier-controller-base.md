# ADR: Three-Tier Controller Base Doctrine

**Status:** Historical (superseded; 2026-05-24)

> Current direction: `OpenController` and each surface-local `ApplicationController` inherit
> directly from `ActionController::Base`. Authentication classification is explicit
> controller/action metadata, not four-way semantic controller inheritance. This ADR remains
> historical context for why controller bases were previously split.

## Context

Rails convention encourages a single `ApplicationController` as the parent of every controller. In
this app that single base has accumulated authentication, authorization, verification, session,
preference, current-context, observability, and finisher concerns, and it is the parent of endpoints
with very different needs.

To express "this endpoint does not need auth" or "this endpoint is open to anyone", the codebase
relies on opt-out flags declared inside controllers that still inherit the heavy stack:

- `public_strict!` — declares a controller as publicly reachable while still inheriting all
  authentication callbacks.
- `guest_only!` — declares a controller as guest-only (signed-in users get redirected away). The
  `Sign::Com::ApplicationController` already carries a `# FIXME: remove this line.` next to its
  `guest_only!` call.

These flags are fail-open: forgetting to declare one leaves the wrong behavior in place, and adding
a new `before_action` to the heavy base silently runs on endpoints that do not need it. The
recently-accepted `adr/public-controller-base.md` removed this opt-out pattern for the machine-style
endpoints (`/health`, `/robots.txt`, `/sitemap.xml`) by introducing a separate `PublicController`
that does not include the auth stack at all.

That decision generalizes. The app actually has three distinct authentication patterns, and each
deserves its own base class so that the inheritance line of a controller declares its authentication
contract:

- **Required.** Must be signed in. The default for app surfaces (dashboards, settings, account
  flows). Today's heavy `<Boundary>::<Tld>::ApplicationController`.
- **Optional.** Reads session if present and exposes `current_user`, but does not enforce. Marketing
  pages, public profiles, help/landing surfaces. Today carried by `public_strict!` on top of the
  heavy base.
- **None.** Does not read session at all. Pure machine endpoints. Today carried by
  `PublicController` (per `adr/public-controller-base.md`).

## Decision

Adopt three boundary-level controller bases per boundary, each expressing one authentication pattern
through inheritance:

```
ActionController::Base
├── ApplicationController     ← Required (signed in or rejected)
├── OpenController            ← Optional (session loaded, not enforced)
└── PublicController          ← None (session never loaded)
```

For each of the three boundaries (`acme`, `sign`, `jump`), all three tiers exist as siblings:

- `Acme::ApplicationController` family (per-TLD as today), `Acme::OpenController`,
  `Acme::PublicController`.
- `Sign::ApplicationController` family, `Sign::OpenController`, `Sign::PublicController`.
- `Jump::ApplicationController`, `Jump::OpenController`, `Jump::PublicController`.

The `OpenController` and `PublicController` of each boundary are introduced at the boundary level
only, not per TLD. This matches the shallow-nesting principle established in
`adr/public-controller-base.md`.

A controller's authentication tier is determined by which base it inherits from. No flag-based
opt-out remains in the long term.

## Semantics

| Concern                        | `ApplicationController` | `OpenController`          | `PublicController` |
| ------------------------------ | ----------------------- | ------------------------- | ------------------ |
| Reads session                  | yes                     | yes                       | no                 |
| Enforces signed-in user        | yes                     | no                        | n/a                |
| `current_user` available       | required                | optional (nil when guest) | not available      |
| Authorization (`ActionPolicy`) | yes                     | optional                  | no                 |
| Verification gates             | yes                     | no                        | no                 |
| Preference / region / theme    | yes                     | yes                       | no                 |
| `Current` / `Actor` lifecycle  | yes                     | yes                       | no                 |
| `RateLimit` default            | yes                     | yes                       | yes                |
| `protect_from_forgery`         | yes                     | yes                       | yes (defense only) |
| `allow_browser`                | yes                     | yes                       | yes                |

`PublicController` semantics are fixed by `adr/public-controller-base.md`. `OpenController`
semantics are settled in detail by the Phase 2 plan (see Migration below); the table above states
the contract that plan must satisfy.

## Naming

- `ApplicationController` — kept. Rails convention. Correct for the most common case (auth
  required). Treated as the default parent for any new controller unless another tier is explicitly
  chosen.
- `OpenController` — new. Reads as "open to anyone", session-aware. Chosen over `GuestController`
  because the existing `guest_only!` flag uses "guest" to mean "guests only" (signed-in users
  rejected); reusing the word for "guests welcome" would be a fail-loud collision.
- `PublicController` — already accepted. Reads as public infrastructure. Pairs with `OpenController`
  as a short, contrasting name.

If naming proves confusing in practice, this ADR is the place to revise. Renaming is cheap relative
to changing the inheritance shape.

## Flag Deprecation

The new tier system replaces the existing flags:

- `public_strict!` → controllers that currently set this flag move to `OpenController`. The flag is
  removed in Phase 3.
- `guest_only!` → not absorbed by the tier system. Its semantics ("signed-in users are redirected
  away") are an authorization rule, not a tier. It will be redesigned during the Phase 2 sign pass;
  the FIXME on `Sign::Com::ApplicationController` is resolved at that point.

## Migration

Phase 1: introduce `PublicController` and migrate machine endpoints. Independent of the rest of this
doctrine.

Phase 2: introduce `OpenController` per boundary and migrate controllers that currently rely on
`public_strict!`. Requires an inventory of every site where `public_strict!` is declared today. The
inventory step decides:

- which controllers belong in `OpenController`;
- the exact include list of `OpenController` (Session, Preference, Current, etc.);
- whether `Open` should also include `ActionPolicy::Controller` (probably yes, with no enforced
  policy by default);
- whether observability (`set_current_observability`, `purge_current`) belongs in `Open`.

The Phase 2 plan is deferred until the inventory exists. This ADR does not freeze `OpenController`'s
include list.

Phase 3: remove `public_strict!` from the codebase. By this point every former call site lives under
`OpenController` or `PublicController`. The flag definition is deleted.

Phase 4: redesign the `guest_only!` flow in `Sign`. Resolve the FIXME on
`Sign::Com::ApplicationController`. May or may not introduce a fourth tier; that decision is
explicitly out of scope here.

## Consequences

- Controller inheritance becomes a self-documenting auth contract: reading
  `class FooController < OpenController` tells you the auth tier without grep-ing for flags.
- A new `before_action` added to `ApplicationController` no longer leaks into open or public
  endpoints, because they no longer descend from `ApplicationController`.
- The class graph gains two new bases per boundary (`OpenController` and `PublicController`), so six
  new files in total across `acme`, `sign`, and `jump`.
- Existing `public_strict!` and `guest_only!` call sites must eventually be migrated. Until that
  finishes, both the old flag pattern and the new tier pattern coexist. This is intentional.
- The doctrine does not promise behavioral parity for migrated controllers. A `public_strict!`
  controller moving to `OpenController` may lose access to a heavy-base concern (for example
  `Authorization::Customer`) that Phase 2 must explicitly decide to keep, drop, or relocate.

## Related

- `adr/public-controller-base.md` — Phase 1 of this doctrine (machine endpoints).
- `adr/actor-current-facade.md` — current request-context facade. This supersedes the old `Jumper`
  request-context direction.
- `adr/four-engine-restoration-and-base-contract.md` — boundary base class contract that this
  doctrine refines.
- Phase 2 plan: deferred, will be created after `public_strict!` inventory.
