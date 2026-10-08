# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpTelephoneAdapterTest < ActiveSupport::TestCase
  test "deliver uses the default outbound sms payload" do
    record = Object.new
    record.define_singleton_method(:number) { "+819012345678" }
    delivered = []

    OutboundSms.stub(:deliver_later, ->(**kwargs) { delivered << kwargs }) do
      OtpTelephoneAdapter.new.deliver(record: record, otp_code: "654321")
    end

    assert_equal(
      [{ to: "+819012345678", title: "Verification code", body: "Your verification code: 654321" }],
      delivered,
    )
  end

  test "deliver rejects unexpected keyword arguments before transport" do
    record = Object.new
    record.define_singleton_method(:number) { "+819012345678" }
    delivered = []

    OutboundSms.stub(:deliver_later, ->(**kwargs) { delivered << kwargs }) do
      assert_raises(ArgumentError) do
        OtpTelephoneAdapter.new.deliver(
          record: record,
          otp_code: "111111",
          encrypted_hotp_token: "ignored",
          email_address: "ignored@example.com",
        )
      end
    end

    assert_empty delivered
  end

  test "deliver uses localized verification payload when requested" do
    record = Object.new
    record.define_singleton_method(:number) { "+819012345678" }
    delivered = []

    OutboundSms.stub(:deliver_later, ->(**kwargs) { delivered << kwargs }) do
      OtpTelephoneAdapter.new.deliver(
        record: record,
        otp_code: "111111",
        message_style: :localized_verification,
      )
    end

    message = I18n.t("sign.telephone_verification.sms_message", code: "111111")

    assert_equal(
      [{ to: "+819012345678", title: "Verification code", body: message }],
      delivered,
    )
  end

  test "deliver never puts the otp code in the sms title" do
    record = Object.new
    record.define_singleton_method(:number) { "+819012345678" }
    delivered = []

    OutboundSms.stub(:deliver_later, ->(**kwargs) { delivered << kwargs }) do
      %i(default localized_verification).each do |message_style|
        OtpTelephoneAdapter.new.deliver(
          record: record,
          otp_code: "222333",
          message_style: message_style,
        )
      end
    end

    delivered.each do |payload|
      assert_not_includes payload.fetch(:title), "222333",
                          "Amazon SNS drops `subject` for direct phone-number publishes, so a code " \
                          "in the title reaches no recipient while still being persisted as a " \
                          "plaintext Solid Queue job argument"
    end
  end
end
