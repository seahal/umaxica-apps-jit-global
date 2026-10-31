# WU-A14 R-AU-46 cleanup-status translation and reference rows (partial WU-A14)

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree carried the uncommitted
  WU-3..WU-7, WU-A1, WU-A6, WU-A13 and the first WU-A14 slice of this cycle plus these changes.
- Requirement: R-AU-46 of `one.md` (one of the `two.md` section 3.11 WU-A14 rows). The reported
  failure was `I18n::MissingTranslationData` for
  `activerecord.attributes.client_sign_up_flow.cleanup_status` when the required reference row
  is absent, rather than the ordinary belongs-to validation failure.
- Root cause check this session:
  - The reference rows are migration-owned
    (`db/op_base_app_migrate/20261006160000_seed_app_sign_flow_reference_data.rb`). The
    development `op_base_app` store currently holds 5 `client_sign_up_flow_cleanup_statuses`
    rows and 15 `client_sign_up_flow_statuses` rows, so the "reference data outside migrations"
    half does not reproduce on the present environment; the runtime-fallback parity the report
    asked for already exists (`ClientSignUpFlowCleanupStatus` includes `ReferenceRecord`,
    matching the flow-family convention in `app/models/concerns/sign_up_flow_ticket.rb`).
  - The translation half was real: `activerecord.attributes.client_sign_up_flow.cleanup_status`
    was missing from both locale files, and this application raises on missing translations in
    development and test, so the belongs-to failure message generation raised instead of
    rendering.
- Changed: added `cleanup_status` attribute copy under `activerecord.attributes.client_sign_up_flow`
  in `config/locales/ja.yml` (`片付け状態参照`) and `config/locales/en.yml`
  (`Cleanup status reference`). No other code path needed a change for this report.
- Public boundary tests (`test/models/client_sign_up_flow_test.rb`, localized):
  - a flow that is otherwise valid but names a non-existent cleanup-status row fails the
    belongs-to validation and renders its failure message in both `:en` and `:ja` without a
    `Translation missing` marker;
  - the humanized attribute name resolves from the added copy in both locales.
  `bin/rails test test/models/client_sign_up_flow_test.rb test/models/operator_sign_up_flow_test.rb test/services/sign_up_artifact_cleanup_test.rb`:
  15 runs, 97 assertions, 0 failures, 0 errors, 0 skips.
- YAML and style: `YAML.load_file` parses both locale files; RuboCop clean on the touched test
  file after style correction. Running RuboCop directly on locale `.yml` files is not a
  meaningful check; the locale content is validated by loading it and by the printer tests above.
- The remaining WU-A14 rows (BL-19's six defect candidates, BL-22's three doc/code
  disagreements, and BL-23's host-default item) are still individually unclassified.
