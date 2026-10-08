# frozen_string_literal: true

require "test_helper"

class EmailCredentialRegistrationOtpResendIssuerTest < ActiveSupport::TestCase
  %w(app com).each do |surface|
    test "#{surface} Email registration resend preserves the original deadline failures and browser" do
      actor, token, email =
        case surface
        when "app"
          owner = Client.create!(status_id: ClientStatus::ACTIVE)
          root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
          candidate = owner.client_emails.create!(
            raw_address: "registration-resend-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
            otp_attempts_count: 1,
          )
          [owner, root, candidate]
        when "com"
          owner = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
          candidate = owner.visitor_emails.create!(
            raw_address: "registration-resend-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
            otp_attempts_count: 1,
          )
          [owner, root, candidate]
        end
      token.rotate_refresh_token!
      nonce = SecureRandom.urlsafe_base64(32)
      issued = EmailCredentialRegistrationOtpIssuer.call(actor: actor, token: token, email: email, browser_nonce: nonce)
      transaction = issued.transaction
      original_deadline = transaction.otp_expires_at
      original_generation = transaction.otp_generation
      scope = { actor: actor, token: token, email: email, transaction: transaction, browser_nonce: nonce }
      later = original_deadline - 30.seconds

      email.class.stub(:database_now, later) do
        transaction.class.stub(:database_now, later) do
          foreign = EmailCredentialRegistrationOtpResendIssuer.call(
            **scope.merge(browser_nonce: SecureRandom.urlsafe_base64(32)),
          )

          assert_equal :unavailable, foreign.status
          assert_equal original_generation, transaction.reload.otp_generation
          resent = EmailCredentialRegistrationOtpResendIssuer.call(**scope)

          assert_predicate resent, :success?
          assert_equal transaction, resent.transaction
          assert_equal original_deadline, transaction.reload.otp_expires_at
          assert_not_equal original_generation, transaction.otp_generation
          assert_equal 1, email.reload.otp_attempts_count
          assert_not transaction.deliver_email_otp!(generation: original_generation, code: issued.code) { flunk }
          assert transaction.deliver_email_otp!(generation: transaction.otp_generation, code: resent.code) { nil }
        end
      end
      [original_deadline, original_deadline + Rational(1, 1_000_000)].each do |expired|
        transaction.class.stub(:database_now, expired) do
          assert_equal :unavailable, EmailCredentialRegistrationOtpResendIssuer.call(**scope).status
        end
      end

      assert_equal 1, email.reload.otp_attempts_count
    end
  end
end
