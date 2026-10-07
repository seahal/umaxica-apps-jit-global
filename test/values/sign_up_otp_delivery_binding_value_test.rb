# frozen_string_literal: true

require "test_helper"

class SignUpOtpDeliveryBindingValueTest < ActiveSupport::TestCase
  test "SMS signup binding requires exactly five fields and an app or com surface" do
    tuple = ["app", "sign_up", "flow_ref", "contact_ref", "0"]

    assert_equal tuple, SignUpOtpDeliveryBindingValue.for_sms(otp_binding: tuple).to_a
    assert_equal "com", SignUpOtpDeliveryBindingValue.for_sms(otp_binding: tuple.dup.tap { |v| v[0] = "com" }).surface
    [nil, [], tuple.take(4), tuple + ["extra"], {}, "binding"].each do |invalid|
      assert_raises(ArgumentError) { SignUpOtpDeliveryBindingValue.for_sms(otp_binding: invalid) }
    end
    ["org", "", nil].each do |surface|
      assert_raises(ArgumentError) do
        SignUpOtpDeliveryBindingValue.for_sms(otp_binding: tuple.dup.tap { |v| v[0] = surface })
      end
    end
  end

  test "signup counter is canonical unsigned 64 bit decimal including zero and its immediate neighbors" do
    ["0", "1", "2", ((1 << 64) - 2).to_s, ((1 << 64) - 1).to_s].each do |counter|
      value = SignUpOtpDeliveryBindingValue.for_sms(otp_binding: ["app", "sign_up", "flow", "contact", counter])

      assert_equal counter, value.counter
    end
    [nil, "", "-1", "01", " 1", "1.0", "1e1", 1, (1 << 64).to_s, "1" * 21].each do |invalid|
      assert_raises(ArgumentError) do
        SignUpOtpDeliveryBindingValue.for_sms(otp_binding: ["app", "sign_up", "flow", "contact", invalid])
      end
    end
  end

  test "email signup references are required only for signup and are never accepted for another purpose" do
    value = SignUpOtpDeliveryBindingValue.for_email(
      purpose: "sign_up", surface: "app", sign_up_flow_ref: "flow", public_id: "contact", sign_up_otp_counter: "1",
    )

    assert_equal({ sign_up_flow_ref: "flow", sign_up_otp_counter: "1" }, value.email_params)
    assert_nil SignUpOtpDeliveryBindingValue.for_email(
      purpose: "sign_in", surface: "app", sign_up_flow_ref: nil, public_id: nil, sign_up_otp_counter: nil,
    )
    assert_raises(ArgumentError) do
      SignUpOtpDeliveryBindingValue.for_email(
        purpose: "sign_up", surface: "app", sign_up_flow_ref: nil, public_id: "contact", sign_up_otp_counter: "1",
      )
    end
    assert_raises(ArgumentError) do
      SignUpOtpDeliveryBindingValue.for_email(
        purpose: "sign_in", surface: "app", sign_up_flow_ref: "flow", public_id: "contact", sign_up_otp_counter: "1",
      )
    end
  end

  test "references retain the existing public id length boundary and reject typed sentinels" do
    ["a", "a" * 20, "a" * 21].each do |reference|
      value = SignUpOtpDeliveryBindingValue.for_sms(otp_binding: ["app", "sign_up", reference, reference, "1"])

      assert_equal reference, value.flow_ref
      assert_equal reference, value.contact_ref
    end
    [nil, "", " ", "a" * 22, 1, []].each do |invalid|
      [2, 3].each do |index|
        tuple = ["app", "sign_up", "flow", "contact", "1"]
        tuple[index] = invalid

        assert_raises(ArgumentError) { SignUpOtpDeliveryBindingValue.for_sms(otp_binding: tuple) }
      end
    end
  end

  test "binding snapshots cannot be rewritten by mutating caller strings or the returned tuple" do
    surface = +"app"
    flow = +"flow"
    contact = +"contact"
    counter = +"1"
    value = SignUpOtpDeliveryBindingValue.for_sms(otp_binding: [surface, "sign_up", flow, contact, counter])
    [surface, flow, contact, counter].each { |string| string.replace("changed") }
    returned_tuple = value.to_a
    returned_tuple[0] = "changed"

    assert_equal ["app", "sign_up", "flow", "contact", "1"], value.to_a
    assert_raises(FrozenError) { value.counter.replace("2") }
  end
end
