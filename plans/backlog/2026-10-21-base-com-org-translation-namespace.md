# Base COM/ORG Copy Still Borrows App Translation Keys

Recorded 2026-10-21 at `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`. Status: backlog. The Auth half of
the same problem was fixed on 2026-10-21 (one.md D-68,
`evidence/2026-10-21-auth-com-org-translation-namespace-Q8T4.md`); the owner asked to keep the Base
half here.

## Problem

`adr/i18n-explicit-translation-keys.md` and `docs/architecture/i18n.md` keep surface copy under its
own namespace (`sign.app` / `sign.com` / `sign.org`, and likewise for `base`). Base COM and ORG
controllers still reference app keys:

| Surface | Keys | Call sites |
|---|---|---|
| Base COM (`app/controllers/base/com`) | 61 | 71 |
| Base ORG (`app/controllers/base/org`) | 20 | 20 |

By namespace (both surfaces): `sign.app.settings` 43, `sign.app.registration` 19,
`sign.app.authentication` 12, `base.app.avatars` 4, `views.sign.app` 2, `sign.app.common` 1.
Counts come from a scan of quoted keys in `app/{controllers,helpers}/base/{com,org}` on 2026-10-21.

## Keys that need a copy decision

Most keys have no surface counterpart yet and can be copied with the text unchanged. These already
have a counterpart (state per bundle `jp/ja jp/en us/ja us/en`: `=` same text, `!` different text,
`-` absent):

| Surface | App key | Counterpart state |
|---|---|---|
| com | `sign.app.registration.email.create.turnstile_validation_failed` | `====` (repoint only) |
| com | `sign.app.registration.email.create.verification_code_sent` | `====` (repoint only) |
| com | `sign.app.settings.show.logout` | `====` (repoint only) |
| org | `sign.app.settings.show.back` | `====` (repoint only) |
| org | `sign.app.authentication.email.edit.submit` | `=---` (fill the missing bundles) |
| org | `sign.app.registration.telephone.create.verification_code_sent` | `=!-!` (decide the text) |
| org | `sign.app.settings.mfa.show.reset_title` | `--!-` (decide the text) |
| org | `sign.app.settings.mfa.show.reset_unavailable` | `!-!-` (decide the text) |

For the Auth half the owner chose the surface's existing text when the two differed (option A);
confirm whether the same rule applies here.

## How the Auth half was done (reuse)

1. Scan the surface's controllers and helpers for quoted `sign.app.*` / `views.sign.app.*` /
   `base.app.*` keys.
2. Copy each key to the surface namespace in the four bundles by line insertion, verifying per
   bundle that no existing key or value changes, that exactly the expected keys are added and that
   values match. Keep bundles where the source is missing missing (no new copy).
3. Repoint the call sites; repoint differing-text keys only after the copy decision.
4. Guard test in the style of
   `test/security/invariants/auth_surface_translation_namespace_invariant_test.rb`, extended to
   `app/{controllers,helpers}/base/{com,org}` and the `base.app` namespace; run it Red first.
5. Run the surface's tests and compare failures with the current full-run baseline; record evidence.

## Related

- one.md D-40 / `two.md`: the `us` bundle overriding `jp` for shared keys is a separate root fix.
- Base COM/ORG controllers move partly to Visa in `two.md` WU-02; doing this before or after that
  move changes which namespace (`base.*` or a Visa namespace) the moved controllers should use.
