# Actor redesign: ActorValuesContext

Date: 2026-06-14

## What changed

`Actor` stays a `ActiveSupport::CurrentAttributes` read facade over a single installed context. The
context value object moved out of `app/models/actor.rb` into `app/values/actor_values_context.rb` as
`ActorValuesContext` (`Data.define`). `Actor::Context` is now a constant alias of
`ActorValuesContext`.

New axes were added to the context, kept distinct from existing ones:

- `surface` (`acme/sign/core/base/palm/help/docs/news/unknown`) — separate from `tld`.
- `transport` (`cookie/bearer/none/unknown`).
- `channel` (`browser/native/server/unknown`).

`browser?`/`native?` read `channel`; `cookie?`/`bearer?` read `transport`. `tld` is unchanged and
not replaced by `surface`.

## Compatibility decisions (durable)

- The canonical principal field is `subject`. `actor` is retained as a reader alias on
  `ActorValuesContext` and as `Actor.actor` / `Actor.actor=` on the facade. The facade's
  `update`/`install_context!` keyword path maps the legacy `:actor` key to `:subject` (see
  `CONTEXT_KEY_ALIASES`). Direct value-object calls (`ActorValuesContext#with` / `#new`) do **not**
  map `:actor`; they require `subject:`.
- `install_context!` keeps the existing incremental keyword form (`install_context!(authn: ...)`)
  which merges onto the current snapshot. It additionally accepts a full `ActorValuesContext`
  positionally. Passing both a positional context and keywords raises `ArgumentError`. The removed
  `:authentication` / `:preference` keys still raise via `Data#with`.
- `empty.subject` is `Unauthenticated.instance` (not `nil`) to preserve existing policy/value-object
  reads (`ApplicationPolicy#actor_resource` and the lifecycle integration snapshots). The
  objective's "prefer `subject: nil`" was intentionally not adopted because anonymity is determined
  by `actor_type == :unauthenticated`, not by a nil subject, and keeping the NULL object avoids
  `nil` leaking into existing direct `context.actor` reads.
- `account` is kept on the context even though it is not in the objective's recommended field list,
  because `Actor.account` is read in the lifecycle.

## transport / channel population (follow-up)

Only `core_browser_api_boundary` sets concrete values today (`surface: :core`, `transport: :cookie`,
`channel: :browser`) because that flow is unambiguously the Core BFF browser cookie path. The
anonymous baseline in `ActorSupport#set_current_context` uses `transport: :none`,
`channel: :unknown`, `surface: :unknown`. There are no consumers of these axes yet, so the rest of
the pipeline leaves them at the safe baseline. TODO left in `actor_support.rb`: derive `surface`
from routing and refine `transport`/`channel` from the resolved credential source when these axes
gain real consumers. Do not guess in a way that could affect policy.

## Lifecycle invariants preserved

- `install_context!` call sites stay within the reviewed allowlist (`actor_context_invariant_test`).
- `Actor.clear` still runs from the `around_action ... ensure` lifecycle and the logout/boundary
  transitions.
- `Actor.current` / `Actor.context` return `ActorValuesContext.empty` when unbound; no request
  reconstruction occurs in the reader.
