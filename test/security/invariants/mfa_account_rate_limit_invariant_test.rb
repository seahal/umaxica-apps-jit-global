# typed: false
# frozen_string_literal: true

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

      # WU-30 removed the APP TOTP second factor; every sign-in second factor is now a Passkey,
      # which is not guessable. A new guessable factor must bring back a per-account limit keyed on
      # the pending MFA actor.
      test "sign-in second-factor controllers are Passkey ceremonies only" do
        controllers = Rails.root.glob("app/controllers/auth/*/sign/in/challenge/*_controller.rb")
          .map { |path| path.basename.to_s }.uniq

        assert_equal ["passkeys_controller.rb"], controllers
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
