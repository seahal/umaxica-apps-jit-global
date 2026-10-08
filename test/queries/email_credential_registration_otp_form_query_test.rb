# frozen_string_literal: true

require "test_helper"

class EmailCredentialRegistrationOtpFormQueryTest < ActiveSupport::TestCase
  %w(app com org).each do |surface|
    test "#{surface} Email registration form reads only its original Root browser and bounded ceremony" do
      actor, token, email =
        if surface == "app"
          owner = Client.create!(status_id: ClientStatus::ACTIVE)
          root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
          candidate = owner.client_emails.create!(
            raw_address: "registration-query-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
          )
          [owner, root, candidate]
        elsif surface == "com"
          owner = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
          candidate = owner.visitor_emails.create!(
            raw_address: "registration-query-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
          )
          [owner, root, candidate]
        else
          owner = Operator.create!(status_id: OperatorStatus::ACTIVE)
          root = OperatorToken.create!(staff: owner, discard_at: 1.day.from_now)
          candidate = owner.staff_emails.create!(
            raw_address: "registration-query-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
          )
          [owner, root, candidate]
        end
      token.rotate_refresh_token!
      nonce = SecureRandom.urlsafe_base64(32)
      issued = EmailCredentialRegistrationOtpIssuer.call(actor: actor, token: token, email: email, browser_nonce: nonce)
      scope = { actor: actor, token: token, email: email, transaction: issued.transaction, browser_nonce: nonce }

      assert EmailCredentialRegistrationOtpFormQuery.call(**scope)
      assert_not EmailCredentialRegistrationOtpFormQuery.call(
        **scope.merge(browser_nonce: SecureRandom.urlsafe_base64(32)),
      )
      assert_not EmailCredentialRegistrationOtpFormQuery.call(**scope.merge(transaction: nil))
      assert_not EmailCredentialRegistrationOtpFormQuery.call(**scope.merge(email: nil))
      assert_not EmailCredentialRegistrationOtpFormQuery.call(**scope.merge(browser_nonce: nil))
      deadline = issued.transaction.otp_expires_at
      [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
        visible =
          issued.transaction.class.stub(:database_now, deadline + offset) do
            EmailCredentialRegistrationOtpFormQuery.call(**scope)
          end

        assert_equal offset.negative?, visible
      end
      issued.transaction.cancel_email_otp!

      assert_not EmailCredentialRegistrationOtpFormQuery.call(**scope)
    end
  end
end
