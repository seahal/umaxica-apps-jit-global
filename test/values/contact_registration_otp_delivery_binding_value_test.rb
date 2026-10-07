# frozen_string_literal: true

require "test_helper"

class ContactRegistrationOtpDeliveryBindingValueTest < ActiveSupport::TestCase
  test "SMS registration binding accepts exactly five fields and preserves each app or com field" do
    %w(app com).each do |surface|
      tuple = [surface, "credential_registration", "12345678-1234-4000-8000-123456789abc", "Contact_1-", "0"]
      value = ContactRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple)

      assert_equal surface, value.surface
      assert_equal "credential_registration", value.purpose
      assert_equal tuple[2], value.flow_ref
      assert_equal tuple[3], value.contact_ref
      assert_equal "0", value.counter
      assert_equal tuple, value.to_a
      assert_equal({ contact_ceremony_transaction_ref: tuple[2], contact_otp_counter: "0" }, value.email_params)
      [tuple.take(4), tuple + ["extra"]].each do |invalid|
        assert_raises(ArgumentError) { ContactRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: invalid) }
      end
    end
  end

  test "SMS binding rejects missing empty and non-array tuple sentinels" do
    [nil, [], {}, "tuple", 0, false].each do |invalid|
      assert_raises(ArgumentError) { ContactRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: invalid) }
    end
    assert_raises(ArgumentError) { ContactRegistrationOtpDeliveryBindingValue.for_sms }
  end

  test "SMS surface and purpose accept only canonical scalar contract strings" do
    { 0 => [nil, "", "org", "APP", :app, [], {}, 0, false],
      1 => [nil, "", "sign_up", "sign_in", :credential_registration, [], {}, 0, false], }.each do |index, invalids|
      invalids.each do |invalid|
        tuple = %w(app credential_registration 12345678-1234-4000-8000-123456789abc contact 1)
        tuple[index] = invalid

        assert_raises(ArgumentError) { ContactRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple) }
      end
    end
  end

  test "flow reference requires UUID version four and rejects malformed or non-scalar references" do
    [nil, "", " ", "transaction", "12345678-1234-3000-8000-123456789abc",
     "12345678-1234-5000-8000-123456789abc", "12345678-1234-4000-0000-123456789abc",
     "12345678-1234-4000-8000-123456789abg", "12345678123440008000123456789abc",
     "12345678-1234-4000-8000-123456789abc\n", [], {}, 0, false,].each do |invalid|
      assert_raises(ArgumentError) do
        ContactRegistrationOtpDeliveryBindingValue.for_sms(
          otp_binding: ["app", "credential_registration", invalid, "contact", "1"],
        )
      end
    end
  end

  test "Contact public reference accepts lengths one through twenty one and rejects zero and twenty two" do
    ["a", "a" * 20, "a" * 21].each do |reference|
      value = ContactRegistrationOtpDeliveryBindingValue.for_sms(
        otp_binding: ["app", "credential_registration", "12345678-1234-4000-8000-123456789abc", reference, "1"],
      )

      assert_equal reference, value.contact_ref
    end
    [nil, "", "a" * 22, " ", "a b", "a/b", "a.b", "a\n", "é", "電話", [], {}, 0, false].each do |invalid|
      assert_raises(ArgumentError) do
        ContactRegistrationOtpDeliveryBindingValue.for_sms(
          otp_binding: ["app", "credential_registration", "12345678-1234-4000-8000-123456789abc", invalid, "1"],
        )
      end
    end
  end

  test "counter accepts canonical zero and unsigned sixty four bit maximum with their representable neighbors" do
    ["0", "1", ((1 << 64) - 2).to_s, ((1 << 64) - 1).to_s].each do |counter|
      value = ContactRegistrationOtpDeliveryBindingValue.for_sms(
        otp_binding: ["com", "credential_registration", "12345678-1234-4000-8000-123456789abc", "contact", counter],
      )

      assert_equal counter, value.counter
    end
    [nil, "", "-1", (1 << 64).to_s, "00", "01", "+1", " 1", "1 ", "1\n", "1.0", "1e1", "０",
     0, 1, [], {}, false,].each do |invalid|
      assert_raises(ArgumentError) do
        ContactRegistrationOtpDeliveryBindingValue.for_sms(
          otp_binding: ["com", "credential_registration", "12345678-1234-4000-8000-123456789abc", "contact", invalid],
        )
      end
    end
  end

  test "email registration requires complete metadata and returns the same fixed tuple and email parameters" do
    %w(app com).each do |surface|
      arguments = {
        purpose: "credential_registration",
        surface:,
        contact_ceremony_transaction_ref: "12345678-1234-4000-8000-123456789abc",
        public_id: "contact",
        contact_otp_counter: "1",
      }
      value = ContactRegistrationOtpDeliveryBindingValue.for_email(**arguments)

      assert_equal [surface, "credential_registration", arguments.fetch(:contact_ceremony_transaction_ref),
                    "contact", "1",], value.to_a
      assert_equal(
        { contact_ceremony_transaction_ref: arguments.fetch(:contact_ceremony_transaction_ref),
          contact_otp_counter: "1", }, value.email_params,
      )
      arguments.each_key do |key|
        assert_raises(ArgumentError) do
          ContactRegistrationOtpDeliveryBindingValue.for_email(**arguments.except(key))
        end
        assert_raises(ArgumentError) do
          ContactRegistrationOtpDeliveryBindingValue.for_email(**arguments.merge(key => nil))
        end
      end
      { surface: "org",
        contact_ceremony_transaction_ref: "12345678-1234-3000-8000-123456789abc",
        public_id: "a" * 22,
        contact_otp_counter: "01", }.each do |key, invalid|
        assert_raises(ArgumentError) do
          ContactRegistrationOtpDeliveryBindingValue.for_email(**arguments.merge(key => invalid))
        end
      end
    end
  end

  test "other email purposes return nil only when both registration metadata fields are nil" do
    [nil, "", "sign_in", "sign_up", "other"].each do |purpose|
      assert_nil ContactRegistrationOtpDeliveryBindingValue.for_email(
        purpose:, surface: "app", contact_ceremony_transaction_ref: nil, public_id: "contact", contact_otp_counter: nil,
      )
      [
        ["12345678-1234-4000-8000-123456789abc", nil], [nil, "0"],
        ["12345678-1234-4000-8000-123456789abc", "0"], ["", nil], [nil, ""], [[], nil], [nil, {}],
      ].each do |reference, counter|
        assert_raises(ArgumentError) do
          ContactRegistrationOtpDeliveryBindingValue.for_email(
            purpose:, surface: "app", contact_ceremony_transaction_ref: reference, public_id: "contact",
            contact_otp_counter: counter,
          )
        end
      end
    end
  end

  test "immutable binding owns snapshots instead of retaining mutable caller strings or exported containers" do
    tuple = [+"app", +"credential_registration", +"12345678-1234-4000-8000-123456789abc", +"contact", +"1"]
    value = ContactRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple)
    tuple.each { |field| field.replace("changed") }
    exported = value.to_a
    exported[0] = "changed"
    parameters = value.email_params
    parameters[:contact_otp_counter] = "changed"

    assert_predicate value, :frozen?
    assert_equal %w(app credential_registration 12345678-1234-4000-8000-123456789abc contact 1), value.to_a
    [value.surface, value.purpose, value.flow_ref, value.contact_ref, value.counter].each do |field|
      assert_raises(FrozenError) { field.replace("changed") }
    end
    assert_equal(
      { contact_ceremony_transaction_ref: "12345678-1234-4000-8000-123456789abc",
        contact_otp_counter: "1", }, value.email_params,
    )
  end
end
