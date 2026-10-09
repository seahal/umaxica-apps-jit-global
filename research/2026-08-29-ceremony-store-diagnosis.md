# What the `*_store.rb` Classes Actually Are

Analysis for #867. **No file is moved by this memo.** The 14 classes in `app/services` whose names
end in `Store` turned out to be four different things, and three of the four should not be called a
Store at all. Deciding where they go needs a design decision first, which is what this records.

## Correction to the inventory

`research/2026-08-29-object-placement-inventory.md` states that all 14 wrap ActiveRecord and that
none touches a cache or object store. Reading each file individually, the first half is wrong for
two of them:

- `webauthn/challenge_store.rb` keeps its entries in the **Rails session**, not in a table. Its
  `current_entries` and `write!` read and write `@session`.
- `dpop_proof_state_store.rb` stores nothing at all.

The second half holds: no file references `Rails.cache`, Valkey, Redis, `Aws::S3`, or ActiveStorage.
So the question "is this an ActiveRecord repository or a real external store?" has a third answer
here — session state — which neither `app/repositories` nor the existing roots express.

## The four shapes

### 1. Surface dispatch plus a write facade — 7 files

`identity_email_ceremony_replay_store.rb`, and the `passkey`, `secret_credential`, `social`,
`step_up`, `telephone`, and `totp` files beside it.

Each pairs a `MODELS` map from surface to model class with a thin write facade:

```ruby
MODELS = {
  "app" => ClientEmailCeremonyTransaction,
  "com" => VisitorEmailCeremonyTransaction,
  "org" => OperatorEmailCeremonyTransaction,
}.freeze

def self.for(surface)
  new(MODELS.fetch(surface.to_s) { raise IdentityEmailCeremonyContract::Error, "surface is invalid" })
end

def create_transaction!(**attributes)
  model_class.create_transaction!(**attributes)
end
```

Two responsibilities in one object. `.for(surface)` derives a model class from a surface — a
Resolver. `create_transaction!` writes — an Operation. `find_transaction!` reads — a Query. The
`Store` name describes none of the three.

The dispatch half is the interesting one: **this is where the app/com/org boundary is expressed in
code**, so `project/surfaces.mdc` governs it, not a persistence concern. `step_up` and `telephone`
additionally carry `consumed?` and `latest_pending_for`, so they are not even uniform with the other
five.

### 2. Keyed lifecycle stores — 3 files

`identity_secret_credential_ceremony_candidate_store.rb`,
`identity_social_ceremony_candidate_store.rb`, `identity_totp_ceremony_candidate_store.rb`.

These are the only files in the group that a Repository name would fit: a `Candidate = Data.define`
value plus a `store! / fetch! / consume! / delete` lifecycle over a candidate table, with digesting
and HMAC keying of their own. The social one is 176 lines and carries `payload_for` and
`callback_result_from` on top.

They still write, so they are not read-side objects, and they are the group most worth leaving alone
until there is a reason to touch them.

### 3. Session-backed store — 1 file

`webauthn/challenge_store.rb`. `issue!`, `consume!`, `consume_with_actor!`, `discard`, plus
`cleanup_expired!` and `evict_oldest!` housekeeping, over entries held in the Rails session. It is a
genuine store; what it stores in is a session, which no current root names.

### 4. Not stores at all — 3 files

- `dpop_proof_state_store.rb` — 12 lines, and the whole body is a `case` returning an ActiveRecord
  class. It is a **Resolver**. The suffix is simply wrong.
- `turnstile_replay_store.rb` — a single `consume!`. It is an **Operation**.
- `social_auth_callback_state_store.rb` — `issue!` and `consume!` delegating to a class chosen by
  `state_class_for(provider)`, which returns `ClientOauthCallbackState` for Google and Apple and
  `nil` otherwise. Dispatch plus writes, and the `nil` branch means an unknown provider silently
  does nothing; `consume!` returns `false`, but `issue!` returns `nil` from the safe navigation
  rather than failing. Worth a second look against `no-silent-fallback` independently of placement.

## Why `app/repositories` was rejected, and still is

A repository layer over ActiveRecord is the pattern most argued against in Rails, because
ActiveRecord already is one. Creating the root would formalize the mixed responsibility in group 1
rather than resolve it, and it would not describe groups 3 or 4 at all.

## Recommendation

Split before placing, in this order:

1. **Group 4 first.** Three files, no design question, each becomes an object that already has a
   root: a Resolver and two Operations. This is a small, safe change that removes the three most
   misleading names.
2. **Group 1 next, as a surfaces change rather than a placement one.** Extract the `MODELS` dispatch
   into a Resolver per ceremony — that is the piece with real value, since it is the surface
   boundary — and let the remaining `create_transaction!` / `find_transaction!` calls go directly to
   the model class at the call site, or become an Operation and a Query if the call sites need them
   named.
3. **Groups 2 and 3 last, or not at all.** They are coherent objects doing one job. The only thing
   wrong with them is that they live in `app/services`, and the cheapest fix is a root that admits
   `Store` — which is a smaller decision than a repository layer.

None of this is scheduled. The point of the memo is that "move 14 stores" was never one task.
