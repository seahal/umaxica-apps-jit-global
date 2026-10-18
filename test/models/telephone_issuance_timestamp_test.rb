# frozen_string_literal: true

require "test_helper"

class TelephoneIssuanceTimestampTest < ActiveSupport::TestCase
  test "APP telephone issuance has an explicit timestamp independent of row creation" do
    telephone = ClientTelephone.new(created_at: 1.year.ago)

    assert telephone.has_attribute?(:otp_last_sent_at)
    assert_not telephone.reregistration_window_active?
  end

  test "COM telephone issuance has an explicit timestamp independent of row creation" do
    telephone = VisitorTelephone.new(created_at: Time.current)

    assert telephone.has_attribute?(:otp_last_sent_at)
    assert_not telephone.reregistration_window_active?
  end

  test "ORG telephone issuance has an explicit timestamp independent of row creation" do
    telephone = OperatorTelephone.new(created_at: Time.current)

    assert telephone.has_attribute?(:otp_last_sent_at)
    assert_not telephone.reregistration_window_active?
  end
end
