# typed: false
# frozen_string_literal: true

require "test_helper"

# The resend endpoint is called from the code-entry page and must answer the
# same way whatever goes wrong inside it: an unexpected failure is reported to
# the error tracker and answered as an invalid state, so a broken resend can
# never become an oracle for whether the address behind the state exists.
class SignInOtpResenderFailuresTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an unexpected failure is reported and answered as an invalid state" do
    reported = []
    exploding = ->(*) { raise IOError, "occurrence store unavailable" }

    Rails.error.stub(:report, ->(error, **context) { reported << [error, context] }) do
      SignInOtpResendState.stub(:parse, exploding) do
        response = SignInOtpResender.new(kind: :email, state: "any-state", surface: :app).call

        assert_not response.resendable
      end
    end

    assert_equal 1, reported.size
    assert_equal "otp_resend", reported.first.last.fetch(:context).fetch(:service)
  end

  test "an unsupported resend kind is refused when the resender is built" do
    assert_raises(ArgumentError) do
      SignInOtpResender.new(kind: :telephone, state: "any-state", surface: :app)
    end
  end
end
