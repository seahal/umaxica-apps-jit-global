# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Enforces the controller inheritance contract:
#   Every peripheral controller must inherit directly from a surface ApplicationController
#   or BareController. Controller-to-controller inheritance is forbidden.
#
# When a violation is fixed, remove it from KNOWN_VIOLATIONS.
# If this test fails with a new violation, the PR must either fix the inheritance
# or add an explicit entry to KNOWN_VIOLATIONS with a documented reason.
class ControllerInheritanceInvariantTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Pre-existing controller-to-controller inheritance violations that have not yet
  # been refactored. Each entry is the controller source path relative to Rails.root.
  # Do not add new entries without a documented reason.
  KNOWN_VIOLATIONS = [
    # Sign::Com::Sign::Up::* inheriting from Sign::Com::Sign::Up::* base controllers.

    # Sign::Com::Sign::Up::Check cross-family inheritance.
    # Note: com/up/check/email/otps and com/up/check/telephone/birthdates and otps are
    # also PERMITTED_LOCAL_BASES for the sign/sign/up layer, so not listed here.

    # Sign::Org::Sign::Up::* inheriting from Sign::Org::Sign::Up::* base controllers.

    # Base identity compatibility shims reuse the existing secrets removal and
    # rotation implementations until the identity/secrets split is flattened.
    "app/controllers/base/app/identity/removals_controller.rb",
    "app/controllers/base/app/identity/rotations_controller.rb",

    # Sign-out completion and emergency revocation controllers currently share
    # the reviewed protocol implementations until those flows are flattened.
    "app/controllers/auth/app/sign/outs/completions_controller.rb",
    "app/controllers/auth/com/sign/outs/completions_controller.rb",
    "app/controllers/auth/org/sign/outs/completions_controller.rb",
    "app/controllers/base/app/sign_outs/completions_controller.rb",
    "app/controllers/base/com/sign_outs/completions_controller.rb",
    "app/controllers/base/org/sign_outs/completions_controller.rb",
    "app/controllers/base/org/support/visitors/sessions/emergency_revocations_controller.rb",
    "app/controllers/core/app/sign/outs/completions_controller.rb",
    "app/controllers/core/com/sign/outs/completions_controller.rb",
    "app/controllers/core/org/sign/outs/completions_controller.rb",
    "app/controllers/side/app/sign/outs/completions_controller.rb",
    "app/controllers/side/com/sign/outs/completions_controller.rb",
    "app/controllers/side/org/sign/outs/completions_controller.rb",
  ].to_set.freeze

  # Controllers that are themselves allowed to be base classes
  # (i.e., other controllers may inherit from these within KNOWN_VIOLATIONS above).
  # These must themselves inherit from ApplicationController or ActionController::Base.
  PERMITTED_LOCAL_BASES = %w(
    app/controllers/auth/app/sign/in/challenges_controller.rb
    app/controllers/auth/app/sign/in/emails_controller.rb
    app/controllers/auth/app/sign/in/guards_controller.rb
    app/controllers/auth/app/sign/in/passkeys_controller.rb
    app/controllers/auth/app/sign/in/secrets_controller.rb
    app/controllers/auth/app/sign/in/sessions_controller.rb
    app/controllers/auth/app/settings/passkeys_controller.rb
    app/controllers/auth/app/sign/up/check/apple/birthdates_controller.rb
    app/controllers/auth/app/sign/up/check/apple/confirmations_controller.rb
    app/controllers/auth/app/sign/up/check/email/birthdates_controller.rb
    app/controllers/auth/app/sign/up/check/email/otps_controller.rb
    app/controllers/auth/app/sign/up/check/google/birthdates_controller.rb
    app/controllers/auth/app/sign/up/check/telephone/birthdates_controller.rb
    app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb
    app/controllers/auth/app/sign/up/check/telephone/passcodes_controller.rb
    app/controllers/auth/app/sign/up/check/telephone/passkeys_controller.rb
    app/controllers/auth/app/sign/up/emails_controller.rb
    app/controllers/auth/app/sign/up/guard/apples_controller.rb
    app/controllers/auth/app/sign/up/guard/emails_controller.rb
    app/controllers/auth/app/sign/up/guard/googles_controller.rb
    app/controllers/auth/app/sign/up/guard/telephones_controller.rb
    app/controllers/auth/app/sign/up/telephones_controller.rb
    app/controllers/auth/app/verification/emails_controller.rb
    app/controllers/auth/com/sign/in/challenges_controller.rb
    app/controllers/auth/com/sign/in/emails_controller.rb
    app/controllers/auth/com/sign/in/guards_controller.rb
    app/controllers/auth/com/sign/in/passkeys_controller.rb
    app/controllers/auth/com/sign/in/secrets_controller.rb
    app/controllers/auth/com/sign/in/sessions_controller.rb
    app/controllers/auth/com/settings/passkeys_controller.rb
    app/controllers/auth/com/sign/up/check/email/birthdates_controller.rb
    app/controllers/auth/com/sign/up/check/email/otps_controller.rb
    app/controllers/auth/com/sign/up/check/telephone/birthdates_controller.rb
    app/controllers/auth/com/sign/up/check/telephone/otps_controller.rb
    app/controllers/auth/com/sign/up/check/telephone/passcodes_controller.rb
    app/controllers/auth/com/sign/up/check/telephone/passkeys_controller.rb
    app/controllers/auth/com/sign/up/emails_controller.rb
    app/controllers/auth/com/sign/up/guard/emails_controller.rb
    app/controllers/auth/com/sign/up/guard/telephones_controller.rb
    app/controllers/auth/com/sign/up/telephones_controller.rb
    app/controllers/auth/com/verification/emails_controller.rb
    app/controllers/auth/org/sign/in/challenges_controller.rb
    app/controllers/auth/org/sign/in/guards_controller.rb
    app/controllers/auth/org/sign/in/passkeys_controller.rb
    app/controllers/auth/org/sign/in/secrets_controller.rb
    app/controllers/auth/org/sign/in/sessions_controller.rb
    app/controllers/auth/org/settings/passkeys_controller.rb
    app/controllers/auth/org/sign/up/invitations_controller.rb
    app/controllers/base/app/jwks_controller.rb
    app/controllers/base/com/jwks_controller.rb
    app/controllers/base/org/jwks_controller.rb
    app/controllers/auth/app/sign/in/challenge/passkeys_controller.rb
    app/controllers/auth/app/sign/in/challenge/totps_controller.rb
    app/controllers/auth/com/sign/in/challenge/passkeys_controller.rb
    app/controllers/auth/org/sign/in/challenge/passkeys_controller.rb
  ).to_set.freeze

  # Patterns that are always forbidden regardless of allowlist status.
  # These detect regressions to the specific patterns cleaned up on this branch.
  FORBIDDEN_PATTERNS = [
    # Check-family controllers must not inherit Checkpoint implementations.
    {
      description: "Check namespace must not inherit Checkpoint namespace",
      glob: "app/controllers/auth/**/*_controller.rb",
      pattern: /class\s+\S+::Checks?(?:::\S+)?Controller\s*<\s*\S+::Checkpoints?(?:::\S+)?Controller/,
    },
    # Sign::*/Sign::In::Check* controllers must not inherit Sign::*/In::Checks*.
    # This was the direct violation fixed on this branch.
    {
      description: "Sign::*/Sign::In::Check* must not inherit Sign::*/In::Checks*",
      glob: "app/controllers/auth/*/sign/in/*checks*_controller.rb",
      pattern: /class\s+\S+Controller\s*<\s*::Sign::\w+::In::Checks?Controller/,
    },
  ].freeze

  # Scans all controller source files and returns paths (relative to Rails.root)
  # whose class declaration inherits from a non-approved base.
  # Approved bases: ApplicationController, BareController, ActionController::Base,
  # RedirectOnlyController, PreAccessController, FullAccessController,
  # PreferencesBaseController, and any class defined in PERMITTED_LOCAL_BASES.
  APPROVED_BASE_PATTERN = /
    ApplicationController
    | BareController
    | ActionController
    | RedirectOnlyController
    | PreAccessController
    | FullAccessController
    | PreferencesBaseController
    | ::Base\b
    | BaseController\b
  /x

  test "no new controller-to-controller inheritance violations are introduced" do
    detected = detect_inheritance_violations

    new_violations = detected - KNOWN_VIOLATIONS
    stale_entries = KNOWN_VIOLATIONS - detected

    messages = []

    unless new_violations.empty?
      header = "New controller-to-controller inheritance violations " \
               "(fix inheritance or add to KNOWN_VIOLATIONS with a documented reason):"
      messages << "#{header}\n#{new_violations.sort.map { |p| "  #{p}" }.join("\n")}"
    end

    unless stale_entries.empty?
      messages << "KNOWN_VIOLATIONS entries that no longer exist or are now fixed (remove them):\n" \
                  "#{stale_entries.sort.map { |p| "  #{p}" }.join("\n")}"
    end

    assert_empty messages, messages.join("\n\n")
  end

  test "forbidden inheritance patterns are not present anywhere" do
    FORBIDDEN_PATTERNS.each do |rule|
      violations =
        Rails.root.glob(rule.fetch(:glob)).filter_map do |path|
          content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
          next unless content.match?(rule.fetch(:pattern))

          path.relative_path_from(Rails.root).to_s
        end

      assert_empty violations,
                   "#{rule.fetch(:description)} -- forbidden inheritance found:\n#{violations.join("\n")}"
    end
  end

  private

  def detect_inheritance_violations
    Rails.root.glob("app/controllers/**/*_controller.rb").filter_map do |path|
      relative = path.relative_path_from(Rails.root).to_s
      next if PERMITTED_LOCAL_BASES.include?(relative)

      content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

      # Extract the inheritance clause from the class declaration.
      match = content.match(/class\s+\S+Controller\s*<\s*(\S+)/)
      next unless match

      superclass_ref = match[1]
      next if superclass_ref.match?(APPROVED_BASE_PATTERN)

      relative
    end.to_set
  end
end
