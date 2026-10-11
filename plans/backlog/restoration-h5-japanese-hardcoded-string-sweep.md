# Restoration H5: Japanese Hardcoded String Sweep (Audit Medium)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `../../adr/audit-findings-2026-03-30.md` (Medium severity)

## Goal

Hardcoded Japanese strings move into `config/locales/ja.yml` with English equivalents in `en.yml`.
Aligns with F3 (no inline `default:` literal).

## Key surface

Views, helpers, controller flash messages.

## Verification

Grep finds no hardcoded Japanese in `.erb` / `.rb` outside locale files. Pages render correctly in
both `en` and `ja`.

## Related
