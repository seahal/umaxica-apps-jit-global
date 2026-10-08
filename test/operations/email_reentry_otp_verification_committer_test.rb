# frozen_string_literal: true

require "test_helper"

class EmailReentryOtpVerificationCommitterTest < ActiveJob::TestCase
  %w(app com org).each do |surface|
    operations = (surface == "org") ? %w(recovery) : %w(recovery withdrawal)
    operations.each do |operation|
      test "#{surface} #{operation} rejects foreign bindings counts wrong code and consumes once" do
        email_model, owner_key, owner =
          case surface
          when "app" then [ClientEmail, :user_id, clients(:one)]
          when "com" then [VisitorEmail, :visitor_id, visitors(:reserved_visitor)]
          when "org" then [OperatorEmail, :staff_id, operators(:one)]
          end
        email = email_model.create!(
          owner_key => owner.id, :raw_address => "reentry-verify-#{SecureRandom.hex(8)}@example.test",
          :confirm_policy => true, :otp_attempts_count => 1,
        )
        browser_ref = SecureRandom.uuid
        transaction = EmailReentryOtpIssuer.call(email: email, operation: operation, session_ref: browser_ref)
        payload = ActiveJob::Arguments.deserialize(enqueued_jobs.last.fetch(:args)).last.fetch(:params)
        code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))
        scope = { email: email,
                  transaction_ref: transaction.transaction_id,
                  operation: operation,
                  session_ref: browser_ref, }

        assert_not EmailReentryOtpVerificationCommitter.call(code: code, **scope.merge(session_ref: SecureRandom.uuid))
        assert_not EmailReentryOtpVerificationCommitter.call(
          code: code, **scope.merge(operation: (operation == "recovery") ? "withdrawal" : "recovery"),
        )
        assert_equal 1, email.reload.otp_attempts_count
        assert_nil transaction.reload.otp_consumed_at
        wrong = (code == "000000") ? "000001" : "000000"

        assert_not EmailReentryOtpVerificationCommitter.call(code: wrong, **scope)
        assert_equal 2, email.reload.otp_attempts_count
        assert_nil transaction.reload.otp_consumed_at
        assert EmailReentryOtpVerificationCommitter.call(code: code, **scope)
        assert_equal 0, email.reload.otp_attempts_count
        assert transaction.reload.otp_consumed_at
        assert_not EmailReentryOtpVerificationCommitter.call(code: code, **scope)
        assert_equal 0, email.reload.otp_attempts_count
      end
    end
  end
end
