# frozen_string_literal: true

require "test_helper"

class EmailCredentialRegistrationOtpDeliveryGuardTest < ActiveSupport::TestCase
  %w(app com org).each do |surface|
    test "#{surface} Email registration late delivery checks its current Root destination and generation" do
      actor, token, email =
        case surface
        when "app"
          owner = Client.create!(status_id: ClientStatus::ACTIVE)
          root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
          candidate = owner.client_emails.create!(
            raw_address: "registration-delivery-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
          )
          [owner, root, candidate]
        when "org"
          owner = Operator.create!(status_id: OperatorStatus::ACTIVE)
          root = OperatorToken.create!(staff: owner, discard_at: 1.day.from_now)
          candidate = owner.staff_emails.create!(
            raw_address: "registration-delivery-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
          )
          [owner, root, candidate]
        when "com"
          owner = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
          candidate = owner.visitor_emails.create!(
            raw_address: "registration-delivery-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
          )
          [owner, root, candidate]
        end
      token.rotate_refresh_token!
      issued = EmailCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, email: email, browser_nonce: SecureRandom.urlsafe_base64(32),
      )
      scope = {
        transaction: issued.transaction,
        email: email,
        generation: issued.transaction.otp_generation,
        destination: email.address,
        code: issued.code,
      }
      transports = 0

      assert EmailCredentialRegistrationOtpDeliveryGuard.call(**scope) { transports += 1 }
      [scope.merge(generation: SecureRandom.uuid), scope.merge(destination: "foreign@example.test")].each do |foreign|
        assert_not EmailCredentialRegistrationOtpDeliveryGuard.call(**foreign) { transports += 1 }
      end
      deadline = issued.transaction.otp_expires_at

      issued.transaction.class.stub(:database_now, deadline - Rational(1, 1_000_000)) do
        assert EmailCredentialRegistrationOtpDeliveryGuard.call(**scope) { transports += 1 }
      end
      [deadline, deadline + Rational(1, 1_000_000)].each do |expired|
        issued.transaction.class.stub(:database_now, expired) do
          assert_not EmailCredentialRegistrationOtpDeliveryGuard.call(**scope) { transports += 1 }
        end
      end
      issued.transaction.cancel_email_otp!

      assert_not EmailCredentialRegistrationOtpDeliveryGuard.call(**scope) { transports += 1 }
      assert_equal 2, transports
      assert_nil issued.transaction.reload.otp_consumed_at
    end
  end
end
