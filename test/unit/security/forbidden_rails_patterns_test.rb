# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ForbiddenRailsPatternsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  FORBIDDEN_PATTERNS = {
    "mass-assignment permit!" => /\bpermit!\b/,
    "unsafe HTML html_safe" => /\bhtml_safe\b/,
    "unsafe HTML raw(...)" => /\braw\s*\(/,
    "disabled TLS verification" => /\bVERIFY_NONE\b/,
    "ignored rescue nil" => /rescue\s+nil\b/,
    "thread-local request state" => /\bThread\.current\b/,
    "class variable request state" => /@@[A-Za-z_]/,
  }.freeze

  SHARED_SELF_SERVICE_RENDER_PATTERN = /render\s+["']acme\/shared\/self_service\/show["']/.freeze

  test "application code does not use forbidden Rails security patterns" do
    offenders =
      application_paths.flat_map do |path|
        relative_path = path.relative_path_from(Rails.root).to_s
        content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

        content.each_line.with_index(1).filter_map do |line, line_number|
          matched_name = FORBIDDEN_PATTERNS.find { |_name, pattern| line.match?(pattern) }&.first
          next unless matched_name

          "#{relative_path}:#{line_number}: #{matched_name}: #{line.strip}"
        end
      end

    assert_empty offenders, "Forbidden security patterns found:\n#{offenders.join("\n")}"
  end

  test "acme controllers do not render the shared self service placeholder directly" do
    offenders =
      Rails.root.glob("app/controllers/acme/**/*.rb").filter_map do |path|
        content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
        next unless content.match?(SHARED_SELF_SERVICE_RENDER_PATTERN)

        path.relative_path_from(Rails.root).to_s
      end

    assert_empty offenders,
                 "Acme controllers must use implicit rendering or action-specific views " \
                 "instead of the shared placeholder:\n" \
                 "#{offenders.join("\n")}"
  end

  # Test-environment detection in app/lib is forbidden by policy: it lets
  # behavior (including auth/verification bypasses) diverge between test and
  # production. A test-only verification bypass was previously removed; this
  # pins it shut.
  TEST_ONLY_BYPASS_PATTERNS = {
    "Rails.env.test? branch in app code" => /Rails\.env\.test\?/,
    "minitest detection in app code" => /defined\?\(\s*Minitest/,
    "rspec detection in app code" => /defined\?\(\s*RSpec/,
    "RAILS_ENV string check in app code" => /ENV\[["']RAILS_ENV["']\]/,
    "removed test verification cookie bypass" => /TEST_VERIFICATION_COOKIE_PREFIX/,
  }.freeze

  test "application code has no test-framework detection or known test-only bypass" do
    offenders =
      application_paths.flat_map do |path|
        relative_path = path.relative_path_from(Rails.root).to_s
        content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

        content.each_line.with_index(1).filter_map do |line, line_number|
          matched_name = TEST_ONLY_BYPASS_PATTERNS.find { |_name, pattern| line.match?(pattern) }&.first
          next unless matched_name

          "#{relative_path}:#{line_number}: #{matched_name}: #{line.strip}"
        end
      end

    assert_empty offenders, "Test-only / test-aware code found in app or lib:\n#{offenders.join("\n")}"
  end

  # Skipping these before_actions removes a verification, step-up, or client
  # authentication guard. It is only safe on the controllers that perform the
  # corresponding flow themselves. Any new file that skips one of these has
  # widened a security boundary and must be reviewed, not copy-pasted.
  SENSITIVE_SKIP_PATTERN =
    /skip_before_action\s+:(?:enforce_verification_if_required|enforce_step_up_prereqs!|authenticate_client!)/

  SENSITIVE_SKIP_ALLOWLIST = %w(
    app/controllers/auth/app/verification/base_controller.rb
    app/controllers/auth/app/verification/emails_controller.rb
    app/controllers/auth/com/verification/base_controller.rb
    app/controllers/auth/com/verification/emails_controller.rb
    app/controllers/auth/org/verification/base_controller.rb
    app/controllers/base/app/edge/v0/cookies_controller.rb
    app/controllers/base/com/edge/v0/cookies_controller.rb
    app/controllers/base/org/edge/v0/cookies_controller.rb
    app/controllers/core/app/edge/v0/cookies_controller.rb
    app/controllers/core/app/edge/v0/dbsc_controller.rb
    app/controllers/core/com/edge/v0/cookies_controller.rb
    app/controllers/core/com/edge/v0/dbsc_controller.rb
    app/controllers/core/org/edge/v0/cookies_controller.rb
    app/controllers/core/org/edge/v0/dbsc_controller.rb
  ).freeze

  test "verification and client-auth before_actions are skipped only in the reviewed allowlist" do
    offenders =
      application_paths.filter_map do |path|
        relative_path = path.relative_path_from(Rails.root).to_s
        content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
        next unless content.match?(SENSITIVE_SKIP_PATTERN)

        relative_path
      end.sort

    assert_equal SENSITIVE_SKIP_ALLOWLIST, offenders,
                 "Files skipping enforce_verification_if_required / enforce_step_up_prereqs! / " \
                 "authenticate_client! changed. Each skip drops a security guard; confirm the " \
                 "controller performs that flow itself and update SENSITIVE_SKIP_ALLOWLIST deliberately.\n" \
                 "added:   #{(offenders - SENSITIVE_SKIP_ALLOWLIST).inspect}\n" \
                 "removed: #{(SENSITIVE_SKIP_ALLOWLIST - offenders).inspect}"
  end

  test "routes do not use catch-all method matching" do
    offenders =
      route_paths.flat_map do |path|
        relative_path = path.relative_path_from(Rails.root).to_s
        content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

        content.each_line.with_index(1).filter_map do |line, line_number|
          next unless line.match?(/via:\s*:all|via:\s*%i\[[^\]]*\ball\b[^\]]*\]|via:\s*\[[^\]]*:all[^\]]*\]/)

          "#{relative_path}:#{line_number}: #{line.strip}"
        end
      end

    assert_empty offenders, "Routes must not use via: :all:\n#{offenders.join("\n")}"
  end

  private

  def application_paths
    Rails.root.glob("{app,lib}/**/*").select { |path| File.file?(path) }
  end

  def route_paths
    [
      Rails.root.join("config/routes.rb"),
      *Rails.root.glob("config/routes/**/*.rb"),
      *Rails.root.glob("config/routing/**/*.rb"),
    ]
  end
end
