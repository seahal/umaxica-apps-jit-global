# frozen_string_literal: true

require "test_helper"

class TelephoneRegistrationRealmAdmissionTest < ActiveSupport::TestCase
  test "registration issuer refuses cross realm actor Root and candidate combinations" do
    [
      [Client.new, VisitorToken.new, ClientTelephone.new],
      [Client.new, ClientToken.new, VisitorTelephone.new],
      [Visitor.new, ClientToken.new, VisitorTelephone.new],
      [Visitor.new, VisitorToken.new, OperatorTelephone.new],
      [Operator.new, OperatorToken.new, ClientTelephone.new],
    ].each do |actor, token, telephone|
      assert_no_difference [-> { ClientTelephoneCeremonyTransaction.count },
                            -> { VisitorTelephoneCeremonyTransaction.count },
                            -> { OperatorTelephoneCeremonyTransaction.count },] do
        assert_raises(ArgumentError) do
          TelephoneCredentialRegistrationOtpIssuer.call(
            actor: actor, token: token, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32),
          )
        end
      end
    end
  end

  test "registration form refuses cross realm proof rather than borrowing another surface policy" do
    assert_raises(ArgumentError) do
      TelephoneCredentialRegistrationOtpFormQuery.call(
        actor: Client.new, token: ClientToken.new, telephone: ClientTelephone.new,
        transaction: VisitorTelephoneCeremonyTransaction.new, browser_nonce: SecureRandom.urlsafe_base64(32),
      )
    end
  end
end
