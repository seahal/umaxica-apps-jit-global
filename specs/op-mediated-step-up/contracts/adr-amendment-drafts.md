# ADR amendment drafts (plan unit 0)

Date: 2026-11-03. Status: accepted by the owner on 2026-11-03 and applied to the four ADRs below
with that date. The text below is the record of what was inserted. When the owner accepts the spec,
each block below is inserted verbatim near the top of its ADR, after the existing status and
amendment notes, in the style the repository already uses ("Amendment (date): ...").

Sources: owner decisions recorded in
`plans/backlog/2026-11-03-op-mediated-step-up-requirements-consolidated.md` and
`plans/backlog/2026-11-03-op-mediated-step-up-standards-alignment.md`;
`specs/op-mediated-step-up/spec.md` (revision 3); `contracts/contract-draft.md` (revision 5) and
`contracts/consumer-inventory.md` (revision 3).

Which text is current today (verified in this session): the Security Mode ADR's E2 is already
superseded by `adr/authentication-security-cycle-consolidation-2026-10-15.md` section 2.2, and the
consolidation ADR sections 2.3, 2.4, 2.5 and 5 carry the current step-up evidence, validity and
`acr` rules. The drafts therefore amend the consolidation ADR as the primary text and add pointers
to the older ADRs.

## 1. `adr/op-auth-rp-authentication-responsibility-separation.md`

Target: section "C. Step-up Authentication: RP → Auth → RP" (line 116), including "An OP visit is
unnecessary solely for step-up" (l.124) and "Direct step-up does not automatically change
`auth_time` or `acr`" (l.129).

```markdown
> **Amendment (YYYY-MM-DD, owner): step-up goes through the OP.** Path C is replaced by RP → OP →
> Auth → OP → RP. The RP asks the OP for re-authentication with an OIDC authorization request
> (`prompt=login`, an essential `acr` of `https://visa.umaxica.app/acr/reauthentication` and an
> essential `auth_time` through `claims`). The OP delegates the ceremony to Auth through the
> existing temporary admission, accepts only evidence allowed for the owner's Security Mode, records
> the event on the grant of the requesting RP session (bound before the ceremony and confirmed at
> the token exchange by the RP's signed client assertion), rotates the refresh token, and issues
> tokens whose `acr`, `amr` and `auth_time` describe the re-authentication. A JWT is never
> rewritten; the OP issues new tokens.
>
> Superseded parts of path C: "An OP visit is unnecessary solely for step-up"; "Direct step-up does
> not automatically change `auth_time` or `acr`"; and the binding of the evidence to a specific
> operation and to the original transaction for single use. The evidence is now one reusable fact
> for the RP session until `auth_time + 300 seconds`.
>
> Retained protections: the Identity, client and live RP session are verified at start and at
> completion; the request is correlated by `state`, `nonce`, PKCE and browser binding; the
> authorization code and the ceremony are single-use (distinct from the reusable evidence); step-up
> never creates, revives or switches a sign-in session; Auth success is evidence, not authorization,
> and the owning application still authorizes the operation. Auth remains neither OP nor RP.
> Specification: `specs/op-mediated-step-up/`.
```

## 2. `adr/authentication-security-cycle-consolidation-2026-10-15.md`

Targets: section 2.3 (maximum validity, evidence binding and single consumption), section 2.4 ("Old
step-up evidence cannot be reused for a different operation"), section 2.2 (deletion
authentication), section 5 (pending `acr`/`amr`).

```markdown
> **Amendment (YYYY-MM-DD, owner): reusable step-up evidence.** For ordinary step-up on the RPs in
> scope of `specs/op-mediated-step-up/` (Base app and Base org first):
>
> - Section 2.3 and 2.4: step-up evidence is no longer bound to the target operation or resource and
>   is no longer consumed. It is one fact, "an active re-authentication was performed in this RP
>   session", carried as the `acr` value `https://visa.umaxica.app/acr/reauthentication` with its
>   `auth_time`, and it is reusable for every sensitive operation of that RP session until
>   `auth_time + 300 seconds` (exclusive, no skew allowance). It is not reusable in another RP
>   session, RP or surface. A sign-in, however recent, never counts as step-up. Refresh can neither
>   create a step-up event nor extend its deadline.
> - Section 2.3: the 15 minute (`NORMAL`) and 5 minute (`ADVANCED`) maxima remain upper bounds;
>   ordinary step-up uses 300 seconds in both modes. The method sets of the table are enforced on
>   the server at Auth and at the OP before the class is issued.
> - Section 2.2: deleting a passkey needs the ordinary step-up class obtained with any method the
>   owner's current Security Mode allows (in `ADVANCED` that is a passkey); the two-passkey minimum
>   and its concurrency requirement are a separate check and are never waived by a successful
>   authentication.
> - Section 5: the pending item on OIDC `acr` is decided for step-up only: the OP issues the class
>   above when, and only when, an accepted step-up ceremony occurred, and RPs authorize
>   step-up-protected operations from that class and `auth_time`. The existing `acr` values (`aal1`
>   and the emergency context) and their meanings are unchanged; `normalize_acr` must not touch the
>   new value.
> - Section 2.5: the owner-initiated `ADVANCED` → `NORMAL` change is satisfied by the ordinary
>   reusable step-up above (obtained with a passkey, because the owner is still in `ADVANCED`); the
>   "purpose-limited, one-time" wording no longer applies. Revocation of every session and refresh
>   token after the change is unchanged.
> - Intentional policy change: for ordinary step-up the requirement that the credential used for the
>   step-up is still accessible (today `ClientPasskeyPolicy#management_credential`) is removed,
>   because the evidence carries no credential reference.
> - Existing enforcement revocation keeps its meaning: a TOTP effect revokes in full every root
>   whose own latest step-up was TOTP, where "latest" now spans the retained root columns and the OP
>   commit facts of every grant the root owns, live or not, kept for the root's lifetime.
> - Operation authorization stays with the owning application; step-up success removes only the
>   step-up prerequisite.
```

Owner decision Q-1 (2026-11-03, "for now"): option (b). The ordinary reusable step-up satisfies the
owner-initiated `ADVANCED` → `NORMAL` change of section 2.5; it is not kept as a separate one-time
purpose. The owner marked this as the current choice, so it may be revisited.

## 3. `adr/authentication-security-mode.md`

Targets: D2 (l.64), D3 (l.65-66), E4 (l.83-87). E2 is already superseded by the consolidation ADR.

```markdown
> **Amendment (YYYY-MM-DD, owner):** D3 and the "one-time consumption of the used step-up evidence"
> clause of E4 are replaced for ordinary step-up by the reusable, RP-session-scoped evidence
> recorded in `adr/authentication-security-cycle-consolidation-2026-10-15.md` (amendment of the same
> date). D2 remains as the upper bound; ordinary step-up uses 300 seconds. The stated rationale
> "one-time, operation-bound evidence removes the reuse the old scope window allowed" no longer
> applies to ordinary step-up; the owner accepted reuse within a 300 second window bound to one RP
> session in exchange for not repeating the ceremony per operation.
```

## 4. `adr/step-up-authentication-redesign.md`

Targets: A1 to A3 (token-bound ticket persistence), C5 (15 minute TTL for repeat operations), D
(scope catalog).

```markdown
> **Amendment (YYYY-MM-DD, owner):** for ordinary step-up on the RPs in scope of
> `specs/op-mediated-step-up/`, evidence is no longer stored on the login token (A1 to A3) and is no
> longer scoped (D): it is the OP-issued event on the requesting RP session's grant, verified by the
> RP from its access token. C5's 15 minute repeat window is replaced by 300 seconds measured from
> the re-authentication. The token-bound tables, the scope catalog and the bootstrap rules (F, G)
> remain for the retained purposes listed in
> `specs/op-mediated-step-up/contracts/consumer-inventory.md` section 6 until a separate change
> removes them.
```

## 5. Not in this draft

- `docs/security/step-up-operation-inventory.md` and the `docs/mermaid` diagrams describe current
  behavior; they change together with the implementation (spec AC-20), not with these amendments.
- `adr/rails-routing-resourceful-policy.md` needs no exception: the routes are class A (contract
  section 11).
- No ADR change is proposed for the retained bootstrap, credential registration, full
  reauthentication or the emergency and Secret refusals.

## 6. Open for the owner

- Q-1 is decided (option (b), for now).
- The amendment date and wording are applied only after the owner accepts the spec.
