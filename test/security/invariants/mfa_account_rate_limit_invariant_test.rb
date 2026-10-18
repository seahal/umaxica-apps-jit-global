# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Security
  module Invariants
    # Second-factor verification must be bounded per account, not only per source IP.
    # An IP-keyed limit alone leaves a distributed attacker unbounded guesses against
    # one account's 6-digit TOTP once the primary factor is established. The email
    # and SMS OTP channels already have a per-account lock
    # (app/models/concerns/otp_lockable.rb); these rules are its equivalent for the
    # factors that are verified in-process.
    #
    # A session-scoped counter is deliberately not used: an attacker discards the
    # session and starts a fresh one, so the counter bounds nothing.
    class MfaAccountRateLimitInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      GUESSABLE_SECOND_FACTOR_CONTROLLERS = {
        "app/controllers/auth/app/sign/in/challenge/totps_controller.rb" => "mfa_totp_create_account",
      }.freeze

      test "every guessable second factor declares a per-account rate limit" do
        GUESSABLE_SECOND_FACTOR_CONTROLLERS.each do |relative_path, rule_name|
          source = Rails.root.join(relative_path).read

          assert_includes source, "name: \"#{rule_name}\"",
                          "#{relative_path} must declare a per-account rate limit named #{rule_name}."
        end
      end

      test "the per-account rules are keyed on the pending MFA actor, not the request IP" do
        GUESSABLE_SECOND_FACTOR_CONTROLLERS.each_key do |relative_path|
          source = Rails.root.join(relative_path).read

          assert_includes source, "actor_id = pending_mfa&.dig(:user_id)",
                          "#{relative_path} must derive its per-account limit key from the pending MFA actor. " \
                          "A key derived from request.remote_ip is the IP limit again under a different name."
        end
      end

      test "the pending MFA session entry keeps no attempt counter that reads as a control" do
        source = Rails.root.join("app/controllers/concerns/authentication_base.rb").read
        set_pending_mfa = source[/def set_pending_mfa!.*?\n  end\n/m].to_s

        assert_not_includes set_pending_mfa, '"attempts" => 0',
                            "A session-scoped attempt counter bounds nothing (the attacker starts a new " \
                            "session) and reads as protection in review. The per-account rate_limit rules " \
                            "are the control."
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
