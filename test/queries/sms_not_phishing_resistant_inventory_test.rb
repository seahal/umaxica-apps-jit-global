# typed: false
# frozen_string_literal: true

require "test_helper"

class SmsNotPhishingResistantInventoryTest < ActiveSupport::TestCase
  test "telephone SMS is an amr value and is not a phishing-resistant method" do
    assert_equal ["sms"],
                 AuthenticationBase::ESTABLISHED_AUTHENTICATION_METHOD_AMR_MAP.fetch("telephone")
    assert_equal ["passkey"],
                 AuthenticationBase::ESTABLISHED_AUTHENTICATION_METHOD_AMR_MAP.fetch("passkey")

    actor = clients(:one)
    result = AuthenticationCredentialInventory.new(actor).call

    assert_not_includes result.phishing_resistant_methods, :telephone
    assert_not_includes result.phishing_resistant_methods, :sms
    assert_not_includes result.aal2_methods, :telephone
  end
end
