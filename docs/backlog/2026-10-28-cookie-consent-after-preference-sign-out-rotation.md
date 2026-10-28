# Cookie consent after Preference sign-out rotation

Status: Taken into the current cycle and decided by the owner later on 2026-10-28 (`one.md` D-55).
At sign-out, consent and Web Push are copied to the new anonymous Preference row, so the same
browser keeps them after sign-out; they are still not linked to the account. The proposal below is
kept as history; it no longer describes an open question.

Earlier status (2026-10-28): deferred by the owner to a subsequent cycle; no consent-policy change was
authorized for the current cycle. The owner explicitly requested this proposal under `docs/backlog/`.

## Scope and owner decision

During OQ-20 discussion, the owner deferred the proposed change to Cookie consent at sign-out.
Preserve current consent behavior while carrying out the separately accepted Preference redesign.
Keep display continuity, anonymous-row replacement and access-key rotation in the current plan.
This deferral does not choose a new retain-versus-reset consent policy and does not authorize a
new prompt, consent copying, or broader consent scope.

The existing browser-local consent boundary and previously accepted removal of the Zenith consent
mirror are separate contracts. Do not interpret deferring this sign-out policy proposal as restoring
account consent mirroring or overriding other accepted requirements. Report a concrete incompatibility
rather than resolving it by silently changing consent behavior.

## Baseline source observations

Read against `b6e7871073bdc43a55fc5f05e8476de8ee71252f` using `git show`:

- `app/controllers/concerns/preference_sign_out_rotation.rb:49-51,84-105,121-139` creates a new
  anonymous Preference row, copies only permitted display settings, and retires the old row.
  Consent is absent from the copy allowlist.
- `app/controllers/concerns/preference_refresh_token_transport.rb:191-210` creates the row and
  invokes `create_preference_options`.
- `app/controllers/concerns/preference_base.rb:136-147,165-175` creates the consent child with
  `consented`, `functional`, `performant`, and `targetable` all false.

These observations explain the baseline path. They do not establish that every logout entry invokes
it or prove actual prompt behavior. No application, browser or database tests were run for this note.

## Options for the next cycle

1. Keep the existing non-copy/default behavior and explicitly define whether and when the browser
   should be asked again after sign-out. This was Codex's recommendation, not an accepted change.
2. Preserve applicable browser-local consent across anonymous-row replacement, with an explicit
   scope, expiry and representation. Do not treat display-only experience as consent authority.

Assess whether a separate browser consent lifecycle is warranted only after identifying a concrete
need. No additional storage or mechanism is selected by this proposal.

## Investigation and acceptance when resumed

- Inventory actual consent collection, storage and use, and the public Base and non-Base logout paths.
- Distinguish anonymous-row/key rotation from the consent decision and from authentication sign-out.
- Define category, expiry, withdrawal and prompt behavior; distinguish consent from Web Push.
- Preserve realm boundaries, Base-only writes, CSRF/Origin protections and GET/HEAD non-mutation.
- Verify public outcomes for consent granted/denied, repeated sign-out, shared-browser use,
  concurrent saves and partial failures. Retain actual validation results when performed.

## Handoff references

Current-cycle working references: `one.md` D-50/OQ-20 and `two.md` section 18.5; these ignored documents
are temporary handoff context. Promote an accepted successor to the owning spec/ADR before coding.
The source references and owner deferral recorded here remain sufficient to revisit the proposal
when the temporary working documents are unavailable.
