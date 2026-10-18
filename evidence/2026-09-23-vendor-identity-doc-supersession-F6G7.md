# Vendor identity documentation supersession

- Date: 2026-09-23
- HEAD before verification: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: existing changes were preserved. No application code, route, registry, credential,
  deployment, or external service was changed.

## Finding

The vendor-facing route inventory, authentication-flow inventory, and normative baseline still
described the historical Acme/Sign authority model as current or normative. In addition, the
partially superseded Base lobby ADR stated the old `base-rails-rp` completion behavior without an
explicit historical qualifier. These documents could cause an implementer or reviewer to restore
the retired shared RP or treat Acme as the physical authority.

## Correction

The documents now carry an explicit current-contract supersession warning and link to the active
Base/Auth ADR and security sequence. The Base lobby sentence now identifies the old Side
`base-rails-rp` completion behavior as migration history only. The historical tables and evidence
were not silently rewritten or deleted.

The follow-up scan found the same ambiguity in the vendor package README, responsibility matrices,
acceptance criteria, cookie/session/token matrix, and the security documents named
`oidc-discovery-profile.md` and `downstream-token-authority.md`. Those files now also identify
their Acme-era authority statements as historical and point to the current Base/Auth contract. No
route, registry, issuer, key, or external registration was changed.

The active contract remains:

- Base is the sole physical OIDC IdP/Authorization Server.
- Auth owns credential ceremony continuity only.
- Base owns Browser Session, RP Session, and OIDC authority.
- First-party browser RP entry is `/sign`; callback is `/sign/callback`.
- Auth credential ceremonies may still use `/sign/in/*`; those are not RP entrypoints.

## Verification

```text
git diff --check
passed
```

The follow-up warning additions were rechecked with the same command after editing; it passed
again. No Rails suite rerun was required for these documentation-only changes. The last relevant
full Rails result at this HEAD remains `11540 runs / 73472 assertions / 0 failures / 0 errors /
8 skips`, recorded in the linked test evidence.

This was a documentation-only correction; the related focused and full Rails results remain those
recorded in `evidence/2026-09-23-retired-rp-reference-cleanup-E5F6.md`.
