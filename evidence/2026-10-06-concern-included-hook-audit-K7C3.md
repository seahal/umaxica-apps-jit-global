# Audit: side effects installed by `included do` in concerns

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`.
- Worktree: dirty during the audit. Six controller concerns had uncommitted changes
  (`authentication_base`, `base_sign_in_limitations`, `base_step_up_cancellation`,
  `base_step_up_completion`, `session_limit_gate`, `surface_chrome`); the counts below describe the
  worktree, not the commit. Of those six, `authentication_base` and `surface_chrome` are among the
  files counted.
- Question: how many files use an `included do` block, and how many of those install side effects
  on the including class, as defined by `.agents/harnesses/rules/generic/rails-concerns.mdc`.
- Scope searched: `*.rb` under `app/`, `lib/`, and `engines/`.

## Result

278 files reference `ActiveSupport::Concern`. 103 of them contain an `included do` block: 28 under
`app/controllers/concerns` and 75 under `app/models/concerns`. None are outside those two
directories.

| Category | Controllers | Models | Total |
| --- | --- | --- | --- |
| Installs callbacks | 18 | 27 | 45 |
| Exposes helpers only, or changes per-request behavior | 5 | 0 | 5 |
| Adds validations, no lifecycle callback | 0 | 35 | 35 |
| Declarations only | 5 | 13 | 18 |

50 files install an unambiguous side effect (the first two rows). Counting implicitly added
validations as well gives 85. 18 files only declare.

## Categories

- Controller callbacks (18): `before_action`, `after_action`, `prepend_before_action`,
  `rescue_from`, or `rate_limit`. `api_content_negotiation`, `app_social_ceremony_entry`,
  `authentication_base`, `authentication_mode_switch_guard`,
  `base_app_avatar_social_graph_actions`, `browser_rp_authentication`,
  `browser_rp_safe_request_refresh`, `browser_rp_unsafe_request_refresh`,
  `core_browser_api_boundary`, `fqdn_availability_gate`, `health_check_rendering`,
  `machine_json_negotiation`, `oauth_authorize_rate_limit`, `oidc_rp_logout_launcher`,
  `publishing_management_cell`, `sign_oidc_logout`, `sign_org_emergency_passkey_ceremony`,
  `sign_org_normal_passkey_ceremony`.
- Controller helpers or per-request behavior (5): `helper_method` only in `preference_core`,
  `sign_out_notice`, `withdrawal_ceremony_reentry`; `inertia_share` in `surface_chrome`; `layout`
  in `surface_inertia_page`.
- Controller declarations only (5): `base_admission_browser_binding`,
  `webauthn_surface_declarable` (`class_attribute`); `sign_up_explicit_step_controller_support`,
  `social_ceremony_entry` (`include` only); `sign_out_inertia_pages` (`define_method`).
- Model lifecycle callbacks (27): `before_validation` in 20 files; the other 7 use
  `before_update`, `before_destroy`, `after_create`, or `after_initialize` without it
  (`auth_admission_binding`, `avatar_assignment_authority_protection`, `collective_unit`,
  `otp_lockable`, `publishing_entry_version_record`, `publishing_taxonomy_snapshot`,
  `publishing_version_media_usage_record`).
- Model validations only (35): `validates` or `validate` with no lifecycle callback. `retainable`
  is counted here and additionally writes to the global `Retainable.registry`.
- Model declarations only (13): `flow_base`, `flow_sign_in`, `flow_sign_out`, `flow_sign_up`,
  `flow_withdrawal`, `notification_owner_record`, `publishing_entry_record`,
  `publishing_entry_revision_record`, `publishing_publication_record`, `reference_record`,
  `single_use_token`, `token_status_management`, `withdrawable`.

Number of files using each macro directly inside `included do`, most frequent first: `validates`
55, `validate` 33, `scope` 32, `include` 28, `before_validation` 20, `class_attribute` 13,
`before_action` 11, `family` 11, `belongs_to` 9, `attribute` 6, `after_action` 5, `encrypts` 5,
`has_many` 5, `cycle_status_column` 5, `helper_method` 4, `after_create` 4, `before_update` 4,
`before_destroy` 4, `prepend_before_action` 3.

## Method

1. `grep -rlE '^\s*included do\b' --include=*.rb app lib engines` listed the 103 files.
2. A throwaway Ruby script took each `included do` body up to the `end` at the same indentation,
   kept the lines one indentation level inside it, and tallied the leading identifier per file.
3. Files were assigned to a category from those macro names by hand.

## Limits

- Classification is by macro name. The block bodies were not read.
- Some of the 18 "declarations only" files may still install side effects: concerns pulled in by a
  nested `include` were not followed, `has_many` options such as `dependent:` were not inspected,
  and the repository macros `cycle_status_column` and `family` were not opened.
- `prepended do` blocks and `self.included` hooks were not searched.

## Comparison with the cop baseline

`.rubocop/architecture_baseline.yml` lists 95 files for `Umaxica/NoConcernInclusionHooks`; the
worktree has 103. Nine files with an `included do` block are absent from the baseline, and one
baselined file (`app/models/concerns/mfa_status_credential.rb`) no longer matches.

`bin/rubocop --only Umaxica/NoConcernInclusionHooks` on the nine files reported 9 offenses in 9
files. None of the nine has uncommitted changes or an inline `rubocop:disable`:

- `app/controllers/concerns/base_admission_browser_binding.rb`
- `app/controllers/concerns/browser_rp_authentication.rb`
- `app/controllers/concerns/browser_rp_safe_request_refresh.rb`
- `app/controllers/concerns/browser_rp_unsafe_request_refresh.rb`
- `app/models/concerns/auth_admission_binding.rb`
- `app/models/concerns/contact_binding.rb`
- `app/models/concerns/session_limit_resolution_transactionable.rb`
- `app/models/concerns/sign_flow_status_backed.rb`
- `app/models/concerns/sign_in_flow.rb`

How these nine were committed past the cop was not investigated.
