# Restoration H5: Japanese Hardcoded String Sweep (Audit Medium)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

Status: Implemented (2026-10-22). See
`evidence/2026-10-22-japanese-hardcoded-string-sweep-H5J2.md`.

## Source

- `../../adr/audit-findings-2026-03-30.md` (Medium severity)

## Goal

Hardcoded Japanese strings move into the four canonical bundles:
`config/locales/{jp,us}/{ja,en}.yml`.
Aligns with F3 (no inline `default:` literal).

## Key surface

Views, helpers, and controller feedback. Rails flash messages remain forbidden.

## Verification

Grep finds no hardcoded Japanese in `.erb` / `.rb` outside locale files. Pages render correctly in
both `en` and `ja`.

## Delivered scope

The remaining matches in application Ruby and ERB were five lines in the shared PWA offline
template. These now use four explicit `pwa.offline` keys in every canonical bundle; the HTML
language follows `I18n.locale`. No controller or helper contained remaining Japanese text.
The framework controller and service worker cache lifecycle remain unchanged.

## Related
