# frozen_string_literal: true

require "test_helper"

class SignUpOtpDeliveryBindingValueTest < ActiveSupport::TestCase
  test "Telephone signup binding requires exactly five fields and an APP or COM surface" do
    tuple = %w(app sign_up flow_ref 12345678-1234-4000-8000-123456789abc
               87654321-4321-4000-b000-cba987654321)

    assert_equal tuple, TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: tuple).to_a
    assert_equal "com",
                 TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: tuple.dup.tap { |v| v[0] = "com" }).surface
    [nil, [], tuple.take(4), tuple + ["extra"], {}, "binding", 0, false].each do |invalid|
      assert_raises(ArgumentError) { TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: invalid) }
    end
    assert_raises(ArgumentError) { TelephoneSignUpOtpDeliveryBindingValue.for_sms }
    ["org", "", nil, "APP", :app, [], {}, 0, false].each do |surface|
      assert_raises(ArgumentError) do
        TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: tuple.dup.tap { |v| v[0] = surface })
      end
    end
    [nil, "", "credential_registration", :sign_up, [], {}, 0, false].each do |purpose|
      assert_raises(ArgumentError) do
        TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: tuple.dup.tap { |v| v[1] = purpose })
      end
    end
  end

  test "signup transaction accepts UUID or NanoID while generation remains an opaque v4 UUID" do
    transaction_reference = "a" * 21
    reference = "12345678-1234-4000-8000-123456789abc"
    generation = "87654321-4321-4000-b000-cba987654321"
    value = TelephoneSignUpOtpDeliveryBindingValue.for_sms(
      otp_binding: ["app", "sign_up", "flow", transaction_reference, generation],
    )

    assert_equal transaction_reference, value.transaction_ref
    assert_equal generation, value.generation
    # Decimal counter bounds are superseded, not UUID arithmetic boundaries.
    ["0", "1", "2", ((1 << 64) - 2).to_s, ((1 << 64) - 1).to_s,
     nil, "", "-1", "01", " 1", "1.0", "1e1", 1, (1 << 64).to_s, "1" * 21,].each do |invalid|
      assert_raises(ArgumentError) do
        TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: ["app", "sign_up", "flow", reference, invalid])
      end
    end
    transaction_invalid = [
      nil, "", " ", [], {}, 0, false, "\xFF", "a" * 20, "a" * 22,
      "a/b", "a.b", "a\n", "é", transaction_reference.encode(Encoding::UTF_16LE),
      "12345678-1234-3000-8000-123456789abc", "12345678-1234-5000-8000-123456789abc",
      "12345678-1234-4000-7000-123456789abc", "12345678-1234-4000-c000-123456789abc",
    ]
    generation_invalid = [
      nil, "", " ", [], {}, 0, false, "\xFF", generation.encode(Encoding::UTF_16LE),
      generation[0...-1], "#{generation}x", "#{generation}\n", generation.upcase,
      "12345678-1234-3000-8000-123456789abc", "12345678-1234-5000-8000-123456789abc",
      "12345678-1234-4000-7000-123456789abc", "12345678-1234-4000-c000-123456789abc",
    ]
    [transaction_invalid, generation_invalid].each_with_index do |invalid_values, index|
      invalid_values.each do |invalid|
        tuple = ["app", "sign_up", "flow", transaction_reference, generation]
        tuple[index + 3] = invalid

        assert_raises(ArgumentError) { TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: tuple) }
      end
    end
  end

  test "Email signup requires complete typed metadata only for signup and refuses mixed other-purpose metadata" do
    arguments = {
      purpose: "sign_up",
      sign_up_flow_ref: "flow",
      sign_up_email_transaction_ref: "12345678-1234-4000-8000-123456789abc",
      sign_up_email_otp_generation: "87654321-4321-4000-b000-cba987654321",
    }
    value = EmailSignUpOtpDeliveryBindingValue.for(**arguments)

    assert_equal arguments.except(:purpose), value.to_h
    arguments.each_key do |key|
      assert_raises(ArgumentError) { EmailSignUpOtpDeliveryBindingValue.for(**arguments.except(key)) }
      assert_raises(ArgumentError) { EmailSignUpOtpDeliveryBindingValue.for(**arguments.merge(key => nil)) }
    end
    [nil, "", "sign_in", "credential_registration", "other"].each do |purpose|
      absent = { purpose:,
                 sign_up_flow_ref: nil,
                 sign_up_email_transaction_ref: nil,
                 sign_up_email_otp_generation: nil, }

      assert_nil EmailSignUpOtpDeliveryBindingValue.for(**absent)
      arguments.except(:purpose).each do |key, reference|
        [reference, "", [], {}].each do |invalid|
          assert_raises(ArgumentError) { EmailSignUpOtpDeliveryBindingValue.for(**absent.merge(key => invalid)) }
        end
      end
    end
  end

  test "signup flow public reference retains length boundaries while transaction accepts NanoID or UUID" do
    transaction_reference = "a" * 21
    reference = "12345678-1234-4000-8000-123456789abc"
    ["a", "aa", "a" * 20, "a" * 21].each do |flow|
      sms = TelephoneSignUpOtpDeliveryBindingValue.for_sms(
        otp_binding: ["app", "sign_up", flow, transaction_reference, reference],
      )
      email = EmailSignUpOtpDeliveryBindingValue.for(
        purpose: "sign_up", sign_up_flow_ref: flow,
        sign_up_email_transaction_ref: transaction_reference, sign_up_email_otp_generation: reference,
      )

      assert_equal flow, sms.flow_ref
      assert_equal flow, email.sign_up_flow_ref
    end
    [nil, "", " ", "a" * 22, 1, [], {}, false, "a/b", "a.b", "a\n", "é", "\xFF"].each do |invalid|
      assert_raises(ArgumentError) do
        TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: ["app", "sign_up", invalid, reference, reference])
      end
      assert_raises(ArgumentError) do
        EmailSignUpOtpDeliveryBindingValue.for(
          purpose: "sign_up", sign_up_flow_ref: invalid,
          sign_up_email_transaction_ref: reference, sign_up_email_otp_generation: reference,
        )
      end
    end
    transaction_invalid = [
      nil, "", " ", "1", [], {}, 0, false, "\xFF", transaction_reference.encode(Encoding::UTF_16LE),
      "a" * 20, "a" * 22, "a/b", "a.b", "a\n", "é",
      "12345678-1234-3000-8000-123456789abc", "12345678-1234-5000-8000-123456789abc",
      "12345678-1234-4000-7000-123456789abc", "12345678-1234-4000-c000-123456789abc",
    ]
    generation_invalid = [
      nil, "", " ", "1", [], {}, 0, false, "\xFF", reference.encode(Encoding::UTF_16LE),
      reference[0...-1], "#{reference}x", "#{reference}\n", reference.upcase,
      "12345678-1234-3000-8000-123456789abc", "12345678-1234-5000-8000-123456789abc",
      "12345678-1234-4000-7000-123456789abc", "12345678-1234-4000-c000-123456789abc",
    ]
    [
      [:sign_up_email_transaction_ref, transaction_invalid],
      [:sign_up_email_otp_generation, generation_invalid],
    ].each do |key, invalid_values|
      arguments = { purpose: "sign_up",
                    sign_up_flow_ref: "flow",
                    sign_up_email_transaction_ref: transaction_reference,
                    sign_up_email_otp_generation: reference, }

      invalid_values.each do |invalid|
        assert_raises(ArgumentError) { EmailSignUpOtpDeliveryBindingValue.for(**arguments.merge(key => invalid)) }
      end
    end
  end

  test "both signup bindings own immutable snapshots despite caller-string and exported-container mutation" do
    tuple = [+"app", +"sign_up", +"flow", +"12345678-1234-4000-8000-123456789abc",
             +"87654321-4321-4000-b000-cba987654321",]
    sms = TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: tuple)
    email = EmailSignUpOtpDeliveryBindingValue.for(
      purpose: tuple[1], sign_up_flow_ref: tuple[2],
      sign_up_email_transaction_ref: tuple[3], sign_up_email_otp_generation: tuple[4],
    )
    expected_sms = tuple.map(&:dup)
    expected_email = { sign_up_flow_ref: tuple[2].dup,
                       sign_up_email_transaction_ref: tuple[3].dup,
                       sign_up_email_otp_generation: tuple[4].dup, }
    tuple.each { |string| string.replace("changed") }
    exported_tuple = sms.to_a
    exported_tuple[0] = "changed"
    exported_parameters = email.to_h
    exported_parameters[:sign_up_email_otp_generation] = "changed"

    assert_predicate sms, :frozen?
    assert_predicate email, :frozen?
    assert_equal expected_sms, sms.to_a
    assert_equal expected_email, email.to_h
    [sms.surface, sms.purpose, sms.flow_ref, sms.transaction_ref, sms.generation,
     email.sign_up_flow_ref, email.sign_up_email_transaction_ref, email.sign_up_email_otp_generation,].each do |field|
      assert_raises(FrozenError) { field.replace("changed") }
    end
  end
end
