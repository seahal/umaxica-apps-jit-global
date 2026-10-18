# typed: false
# frozen_string_literal: true

require "test_helper"

# Invalid browser state is a normal refusal; a dependency failure is not evidence
# that a destination is nonexistent and must remain an explicit operational error.
class SignInOtpResenderFailuresTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    @ceremony = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "local_sign_in", local_sign_in_flow_ref: admission.transaction.public_id,
    ).first
    @ceremony.issue_email_otp!(contact: nil, destination: "failure-resend-#{SecureRandom.hex(8)}@example.test")
  end

  test "an unexpected dependency failure is reported and raised rather than classified as invalid state" do
    reported = []
    exploding = ->(*) { raise IOError, "occurrence store unavailable" }

    Rails.error.stub(:report, ->(error, **context) { reported << [error, context] }) do
      SignInOtpResendState.stub(:parse, exploding) do
        error =
          assert_raises(IOError) do
            SignInOtpResender.new(
              kind: :email, state: "any-state", surface: :app,
              browser_binding: @ceremony.sid_digest, ceremony: @ceremony,
            ).call
          end
        assert_equal "occurrence store unavailable", error.message
      end
    end

    assert_equal 1, reported.size
    assert_equal "otp_resend", reported.first.last.fetch(:context).fetch(:service)
    assert_not reported.first.last.fetch(:handled)
  end

  test "an unsupported resend kind is refused when the resender is built" do
    error =
      assert_raises(ArgumentError) do
        SignInOtpResender.new(
          kind: :telephone, state: "any-state", surface: :app,
          browser_binding: @ceremony.sid_digest, ceremony: @ceremony,
        )
      end
    assert_equal "unsupported sign-in OTP resend kind: telephone", error.message
  end
end
