# I18n Missing Translation Detection Implementation Notes

## Context

- Reported symptom: `https://www.umaxica.org/preference/timezone/edit?ri=us` rendered
  `Timezone Settings` and `Asia Tokyo` in English — humanized key fragments, not translations.
- Reported hypothesis: `config.i18n.raise_on_missing_translations` had been turned off.
- Related decisions/docs: `research/i18n-inline-default-literal-rule.md` (accepted 2026-04-17),
  `.agents/harnesses/rules/generic/no-silent-fallback.mdc`,
  `docs/reference/repository-language-policy.md`
- Implementation date: 2026-08-13

## Findings

The hypothesis was wrong. `raise_on_missing_translations` was already enabled everywhere: `:strict`
in `config/environments/development.rb:97` and `config/environments/test.rb:64`, `true` in
`config/environments/production.rb`. Three separate mechanisms were suppressing it.

1. **`t(..., default: ...)` call sites.** A translation call that carries a `default:` never raises
   `I18n::MissingTranslation`, so `raise_on_missing_translations` can never fire for it.
   `app/controllers/concerns/base_preference_screen_page.rb` put a `default:` on nearly every
   lookup, and line 148 additionally passed `fallback: false`, so the English page could not even
   fall back to Japanese — it landed on `default_label`, the humanized key fragment the user saw.

2. **Duplicate YAML mapping keys.** The four locale bundles contained 53 duplicated keys (`en.auth`
   three times in `config/locales/jp/en.yml`, `en.base` twice, `en.acme.app` twice, and so on). YAML
   resolves a duplicate by discarding the earlier block entirely, which silently dropped **1091
   translation keys** across the four bundles at load time.

3. **A hardcoded load path.** `config/initializers/locale.rb` rejected every default path under
   `config/locales` and re-added exactly four literal filenames, so any bundle added later would be
   ignored without any error.

## Decisions Made During Implementation

- Decision: deep-merge the duplicated YAML blocks and rewrite the four bundles with sorted keys.
  - Why: the merge is a strict superset — it recovers 1091 keys and changes no existing value.
    Sorting makes a future duplicate visible in review instead of hiding hundreds of lines apart.
  - Alternatives considered: fixing the 53 sites by hand (same result, far more error-prone) and
    leaving them with only a guard test (leaves the 1091 keys lost).
  - Verified: a key-by-key before/after comparison showed 0 removed keys and 0 changed values other
    than the two intentional edits below.

- Decision: production keeps `raise_on_missing_translations = true` rather than `:strict`.
  - Why: the user chose not to turn a missing translation into a production 500. Detection now
    happens in development and test, where `:strict` is on and no `default:` masks it.
  - Follow-up: revisit once the remaining locale asymmetry (below) is burned down.

- Decision: `preference_option_translation_key` for the region screen now uses the caller's surface
  instead of the hardcoded `acme.app.preferences.regions.select_region_selector.*`.
  - Why: the hardcoded `app` scope was a cross-surface read from the org and com screens, which
    `.agents/harnesses/rules/project/surfaces.mdc` treats as a defect. The alias cascade into
    `base.com.preference.locale.edit.timezone_options.*` was the same problem and is also gone.

- Decision: `app/views/auth/shared/preference/selectable.html.erb` now reads the `base.*` tree.
  - Why: it previously read `acme.<surface>.preference.<type>.edit.*`, keys that exist for no
    surface, so every lookup landed on its `default:`. The live Inertia path renders the same screen
    from `base.<surface>.preference.<type>.edit.*`, so the template was aligned to it rather than
    given a second, parallel key tree.

- Decision: `preference_option_label` no longer titleizes an unknown option.
  - Why: a humanized option name is exactly the failure the user reported. Its unit test in
    `test/controllers/concerns/preference/core_test.rb` was rewritten to assert the raise.

- Decision: fixed `テーマ of Choice` → `テーマの選択` in the ja bundles.
  - Why: mixed-language UI copy, contrary to `docs/reference/repository-language-policy.md`. Found
    while filling the theme screen keys.

## Deviations From Plan

- Change: the plan scoped the work to removing `default:` and filling the preference keys. The
  duplicate-YAML-key defect was found during implementation and fixed as well.
  - Why: it was the largest single cause of missing translations at runtime, and the `default:`
    removal would have converted many of those silent losses into raises.
  - Risk: the four bundles are fully rewritten, so the diff is large. Content equivalence was
    verified key-by-key rather than by reading the diff.

- Change: locale asymmetry between `en` and `ja` was closed for the preference surface only.
  - Why: after the merge, 683 keys remain that exist in `ja` but not `en`, and 741 the other way,
    almost all outside preferences (`sign.*` 362, `controller.*` 141, `activerecord.*` 47). These
    are product copy; inventing 1400 strings was out of scope for this fix.
  - Risk: bidirectional fallbacks (`en → ja`, `ja → en`) mean these render in the _other_ language
    rather than raising, so they are invisible to `raise_on_missing_translations` by design.
  - Follow-up: promote the `en`/`ja` key-symmetry burn-down into the planning system. A symmetry
    assertion cannot be added as a guard until the backlog is closed.

## Regression Guards Added

`research/i18n-inline-default-literal-rule.md` deferred a regression test as optional. It is now
mandatory and enforced:

- `test/initializers/locale_bundle_integrity_test.rb` — no duplicate YAML key in any bundle; every
  bundle under `config/locales` is on the load path; no `t(..., default:)` anywhere in `app/`.
- `test/integration/preference_screen_localization_test.rb` — all 11 preference screens on all three
  surfaces, in both regions and both locales, plus an assertion that no timezone choice label is a
  humanized key fragment.

## Review Notes

- Tests run: full `bin/rails test` — 10100 runs, 56642 assertions, 2 failures, 0 errors, 1 skip.
- Both failures are pre-existing and unrelated to this change:
  - `ViteAssetNonceTest#test_every_Vite_asset_tag_on_an_Inertia_page_carries_the_response_nonce` —
    the entrypoint emits no modulepreload links in this environment; reproduced on a stashed
    baseline.
  - `Security::Invariants::ForbiddenPatternsInvariantTest` — an unstaged in-flight refactor in
    `auth/app/sign/{ins,ups}_controller.rb` reflowed `redirect_to(..., allow_other_host: true)`
    across lines and switched `params[:ri]` to `current_region_identifier`, so it no longer matches
    the allowlist regexes at `test/security/invariants/forbidden_patterns_invariant_test.rb:194` and
    `:213`. Whoever owns that refactor should update those two allowlist entries. This change only
    removed a `default:` from a different line of the same files.
- `errors.fqdn_availability.unavailable` was missing from both locales and broke
  `test/integration/fqdn_availability_gate_test.rb` before this change; the key was added.
- Lint: `rubocop` clean on all changed Ruby files; `erb_lint` clean on the changed templates.
- Documentation promotion needed: fold the enforced regression policy back into
  `research/i18n-inline-default-literal-rule.md`, which still records it as optional.
