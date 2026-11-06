# WU-A14 host-default removal

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was already dirty and had 534 tracked
or untracked status entries at verification time; unrelated changes were preserved. The two
implementation files in this slice had no pre-existing diff. `.env.container.devcontainer` was
already modified before this slice and was not edited here. The local ignored `four.md` note was
updated; Git does not report that file because `.gitignore` excludes it.

Removed the development-host argument from every `HostFamilyValues#origin` call. The method now
reads the selected environment key with one-argument `fetch` in every environment. Existing
environment values are selected by boundary: ACME uses `PRIVATE_BASE_*_URL`, Palm uses
`PUBLIC_PALM_SERVICE_URL`, and Help/Info use `PRIVATE_HELP_*_URL` / `PRIVATE_INFO_*_URL`; previously
accepted unprefixed service keys remain usable when the canonical key is absent. Base's existing
`BASE_*_URL` versus `PUBLIC_BASE_*_URL` precedence was left unchanged. No environment file values
were added.

Verification:

- Before and after the change, `test/lib/config_values/host_family_values_test.rb` passed: 14 runs,
  81 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop lib/config_values_host_family_values.rb test/lib/config_values/host_family_values_test.rb`
  reported no offenses; both files passed `ruby -c`; `git diff --check` passed.
- A development Rails boot via `bin/rails runner` with `.env.container.devcontainer` loaded exited
  successfully. It resolved ACME to `base.*.localhost`, public Base to `www.umaxica.*`, Palm to
  `palm-jp.umaxica.app`, and Help/Info to their configured `*.localhost` hosts. This matches the
  former development values without a code-side host default.

No full suite, production boot, deployed Host Authorization path, or external service was checked.
The other BL-23 Visa coverage items and the remaining WU-A14 work remain separate.
