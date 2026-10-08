# frozen_string_literal: true

require "test_helper"

class TelephoneRegistrableTest < ActiveSupport::TestCase
  test "registration issuance refuses a missing actor without creating a ceremony" do
    assert_no_difference -> { ClientTelephoneCeremonyTransaction.count } do
      assert_raises(ArgumentError) do
        TelephoneCredentialRegistrationOtpIssuer.call(
          actor: nil, token: ClientToken.new, telephone: ClientTelephone.new,
          browser_nonce: SecureRandom.urlsafe_base64(32),
        )
      end
    end
  end

  test "registration issuance refuses an empty actor without creating a ceremony" do
    assert_no_difference -> { ClientTelephoneCeremonyTransaction.count } do
      assert_raises(ArgumentError) do
        TelephoneCredentialRegistrationOtpIssuer.call(
          actor: "", token: ClientToken.new, telephone: ClientTelephone.new,
          browser_nonce: SecureRandom.urlsafe_base64(32),
        )
      end
    end
  end

  test "registration form denies a missing candidate or transaction rather than reconstructing Source proof" do
    actor = Client.new
    token = ClientToken.new
    nonce = SecureRandom.urlsafe_base64(32)

    assert_not TelephoneCredentialRegistrationOtpFormQuery.call(
      actor: actor, token: token, telephone: nil, transaction: ClientTelephoneCeremonyTransaction.new,
      browser_nonce: nonce,
    )
    assert_not TelephoneCredentialRegistrationOtpFormQuery.call(
      actor: actor, token: token, telephone: ClientTelephone.new, transaction: nil,
      browser_nonce: nonce,
    )
  end
end
