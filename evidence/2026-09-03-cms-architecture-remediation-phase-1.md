# CMS architecture remediation phase 1

- Date: 2026-09-03
- Scope: Rails publishing/CMS reproducibility, migration-path ownership, reconstruction
  authority, architecture guards, 3x4 matrix documentation. Edge CMS wiring not in
  scope.
- Worktree: umaxica-apps-jit-global at `80dc4151fce6d290c8a5ead581126adc975b62c7`
  (feature branch; not reset to audited `fd328d64`).
- Edge inspected: umaxica-apps-edge `6cd77c4422ed85c51e6014de550d628e2e4764b2`
  (matches audited SHA). No Edge files changed.

## Commands

```text
bin/rails test test/lib/entra_omniauth_boot_credentials_test.rb \
  test/tooling/database_migration_path_ownership_test.rb \
  test/tooling/database_reconstruction_authority_test.rb \
  test/tooling/content_surface_matrix_doc_test.rb \
  test/models/publishing/architecture_guard_test.rb
# 18 runs, 113 assertions, 0 failures

bin/rails test test/models/publishing/ \
  test/contracts/publishing_entry_api_contract_test.rb \
  test/queries/publishing_published_entries_query_test.rb \
  test/services/org_entra_sign_in_preflight_test.rb
# 97 runs, 353 assertions, 0 failures

bin/rails test test/initializers/omniauth_test.rb \
  test/unit/security/forbidden_rails_patterns_test.rb
# included in a 38-run combined pass, 0 failures

bin/rubocop lib/entra_omniauth_boot_credentials.rb \
  config/initializers/omniauth.rb \
  test/lib/entra_omniauth_boot_credentials_test.rb \
  test/tooling/database_migration_path_ownership_test.rb \
  test/tooling/database_reconstruction_authority_test.rb \
  test/tooling/content_surface_matrix_doc_test.rb \
  test/models/publishing/architecture_guard_test.rb
# 7 files inspected, no offenses
```

## Result

Pass on the commands above. Publishing tests continue to use the existing test
database reconstructed from migrations; committed `db/*_structure.sql` files
remain header stubs.

## Remaining issues

- Region semantics unresolved (uniqueness vs CHECK).
- Edge CMS consumption not implemented; 12-cell Edge client extraction deferred.
- `publishing_media_usages` exclusive-arc polymorphism unchanged.
- Stub structure.sql dumps not regenerated.
- Public host spelling differs between Rails (`docs.jp.umaxica.app`) and Edge
  README (`docs.umaxica.app`).
