# Removing the Custom `bin/` Scripts and Their Documentation Implementation Notes

## Context

- Original plan/spec: operator decision in session, 2026-09-01. `bin/` is to carry Rails and gem
  generated binstubs only; a custom script does not belong there.
- Related decisions/docs/plans: `docs/operations/cloudflare-private-origin.md`,
  `docs/operations/development-credential-provisioning.md`,
  `docs/operations/fakecloud-migration-verification.md`, `docs/operations/local-aws-fakecloud.md`,
  `docs/operations/development-host-port-exposure.md`,
  `docs/architecture/cloudflare-request-paths.md`.
- Implementation date: 2026-09-01

## Context Found Before Changing Anything

Two custom scripts were in scope. Neither had a live consumer.

`bin/tunnel-origin-check` was deleted on 2026-08-30 in `cf448f19e`, whose only other change was
`docs/reference/repository-language-policy.md`. The deletion was deliberate, but no documentation
was updated with it, so six standing claims across four files described a command that no longer
existed — including Gate 1 of the private-origin contract and its entire "Running the Transport
Probe" section.

`bin/setup-dev-secrets` still existed and still generated and registered fourteen Podman Secrets. It
was already orphaned: `64f66841b` (2026-08-31) moved the stack to fixed literals, `compose.yaml`
declares no `secrets:` block, no service consumes a `dev_*` secret, and `devcontainer.json` declares
no `initializeCommand`. `docs/operations/development-credential-provisioning.md` had already been
rewritten for a world without it and asserted `.secrets/` "is no longer written by anything in this
repository", which the script's continued existence contradicted.

## Decisions Made During Implementation

- Decision: delete `bin/setup-dev-secrets` rather than relocate it.
  - Why: it registers secrets nothing reads. Relocating it would preserve a dead code path and keep
    `.secrets/` populated with credential-shaped files that have no consumer.
  - Alternatives considered: moving it under `test/tooling/` alongside the compose contract tests.
    Rejected — that directory holds Minitest files, and the script is neither a test nor needed.
  - Follow-up needed: the file could not be deleted from inside `core`.
    `.devcontainer/compose.override.yml` binds `./bin` with `read_only: true`, so the removal must
    be run from a host terminal.

- Decision: document the transport probe as a manual procedure instead of restoring a script.
  - Why: the capability is still a gate — it is the only check that proves the _connector's_ network
    position reaches Rails, rather than that Rails is up. The objection was to the location, not the
    function, and a documented host procedure needs no home in `bin/`.
  - Alternatives considered: dropping Gate 1 and rewriting the invariant around `/ready` plus the
    Host Authorization contract test. Rejected — `/ready` proves the tunnel is connected and says
    nothing about origin reachability, which is exactly the failure mode seen earlier the same day.
  - Follow-up needed: the procedure has not been executed. `podman` is absent from `core`.

- Decision: have the probe read the alias list from the running `core` container rather than writing
  the twenty-nine `*.localhost` names into the document.
  - Why: `compose.yaml`'s `frontend` `aliases:` block is the single source for those names. A second
    copy in prose drifts silently, and a probe that misses an alias reports a pass it did not earn.
  - Alternatives considered: listing the names inline for copy-paste convenience. Rejected.
  - Follow-up needed: none.

- Decision: leave every reference under `notes/`, `plans/`, and `docs/audits/` untouched.
  - Why: those are dated records of what was true when written. Rewriting them to match current code
    would destroy the evidence they exist to hold.
  - Alternatives considered: adding supersession markers, the pattern
    `notes/implementation/2026-08-10-development-tunnel-access-verification.md` already uses for its
    own 2026-08-11 and 2026-08-16 changes. Not done here; the operator asked that the evidence be
    left alone. Worth revisiting for
    `notes/implementation/2026-08-23-cloudflare-tunnel-restart-storm.md:87`, which describes the
    deleted script in the present tense.
  - Follow-up needed: none blocking.

## Deviations From Plan

- Change: `docs/operations/fakecloud-migration-verification.md` Part 1 was closed out rather than
  having its 1.1 edit applied.
  - Why: 1.2 and 1.3 were verified as already landed in `64f66841b`, and 1.1 asked for an edit to a
    script that is being deleted. Its blockquote claimed `podman compose up` fails until all three
    are applied, which is no longer true.
  - Risk: low. The document's own status line says it should be deleted once finished; that decision
    is left to its owner rather than taken here.
  - Follow-up: decide whether the document has any remaining purpose. Part 3 records that no runtime
    verification of fakecloud was ever performed, which is still outstanding.

## Review Notes

- Tests run: `bin/rails test test/tooling/ test/config/host_authorization_contract_test.rb` — 32
  runs, 229 assertions, 0 failures, 0 errors, 0 skips.
- Tests not run: the full suite; the transport probe itself, which needs a host terminal.
- Documentation promotion needed: none. No new standing rule was created — the private-origin
  contract keeps the same six gates, with Gate 1 restated as the procedure it always described.
