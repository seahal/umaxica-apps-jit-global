# frozen_string_literal: true

require "test_helper"

class ContactRegistrationOtpDeliveryBindingValueTest < ActiveSupport::TestCase
  test "Telephone registration accepts exact five-field APP COM and opaque ORG bindings" do
    %w(app com org).each do |surface|
      tuple = [surface, "credential_registration", "12345678-1234-4000-8000-123456789abc",
               (surface == "org") ? "OrgContact_1234567890" : "Contact_1-", "87654321-4321-4000-b000-cba987654321",]
      value = TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple)

      assert_equal surface, value.surface
      assert_equal tuple[1], value.purpose
      assert_equal tuple[2], value.transaction_ref
      assert_equal tuple[3], value.candidate_ref
      assert_equal tuple[4], value.generation
      assert_equal tuple, value.to_a
      [tuple.take(4), tuple + ["extra"]].each do |invalid|
        assert_raises(ArgumentError) {
          TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: invalid)
        }
      end
    end
  end

  test "Telephone binding rejects missing empty and non-array tuple sentinels" do
    [nil, [], {}, "tuple", 0, false].each do |invalid|
      assert_raises(ArgumentError) {
        TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: invalid)
      }
    end
    assert_raises(ArgumentError) { TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms }
  end

  test "Telephone surface and purpose require canonical scalar strings and ORG requires opaque candidate ownership" do
    { 0 => [nil, "", "dev", "APP", :app, [], {}, 0, false],
      1 => [nil, "", "sign_up", "sign_in", :credential_registration, [], {}, 0, false], }.each do |index, invalids|
      invalids.each do |invalid|
        tuple = %w(app credential_registration 12345678-1234-4000-8000-123456789abc contact
                   87654321-4321-4000-b000-cba987654321)
        tuple[index] = invalid
        assert_raises(ArgumentError) {
          TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple)
        }
      end
    end
    ["a" * 21, "A_-" + ("9" * 18)].each do |candidate|
      tuple = ["org", "credential_registration", "12345678-1234-4000-8000-123456789abc",
               candidate, "87654321-4321-4000-b000-cba987654321",]

      assert_equal candidate,
                   TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple).candidate_ref
    end
    [nil, "", "0", "1", "01", "-1", "+1", "contact", "a" * 20, "a" * 22, ("a" * 20) + "\0"].each do |candidate|
      assert_raises(ArgumentError) do
        TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
          otp_binding: ["org", "credential_registration", "12345678-1234-4000-8000-123456789abc",
                        candidate, "87654321-4321-4000-b000-cba987654321",],
        )
      end
    end
  end

  test "generation remains a UUID while transaction references accept UUID or NanoID" do
    uuid = "12345678-1234-4000-8000-123456789abc"
    %w(8 9 a b).each do |variant|
      reference = uuid.sub("-8000-", "-#{variant}000-")
      value = EmailCredentialRegistrationOtpDeliveryBindingValue.for(
        purpose: "credential_registration", contact_ceremony_transaction_ref: reference,
        contact_otp_generation: reference,
      )

      assert_equal reference, value.contact_otp_generation
      assert_equal reference, value.contact_ceremony_transaction_ref
    end
    nanoid = "A1_b2-C3d4E5f6G7h8I9j"
    value = EmailCredentialRegistrationOtpDeliveryBindingValue.for(
      purpose: "credential_registration", contact_ceremony_transaction_ref: nanoid,
      contact_otp_generation: uuid,
    )

    assert_equal nanoid, value.contact_ceremony_transaction_ref
    assert_raises(ArgumentError) do
      EmailCredentialRegistrationOtpDeliveryBindingValue.for(
        purpose: "credential_registration", contact_ceremony_transaction_ref: uuid,
        contact_otp_generation: nanoid,
      )
    end
    [nil, "", " ", "transaction", uuid[0...35], uuid + "0", uuid.upcase,
     uuid.sub("-4000-", "-3000-"), uuid.sub("-4000-", "-5000-"),
     uuid.sub("-8000-", "-7000-"), uuid.sub("-8000-", "-c000-"),
     uuid.sub("-8000-", "-0000-"), uuid.sub("9abc", "9abg"), uuid.delete("-"),
     uuid + "\n", "\xFF", uuid.encode("UTF-16LE"), [], {}, 0, false,].each do |invalid|
      [2, 4].each do |index|
        tuple = ["app", "credential_registration", uuid, "contact", uuid]
        tuple[index] = invalid
        assert_raises(ArgumentError) {
          TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple)
        }
      end
      %i(contact_ceremony_transaction_ref contact_otp_generation).each do |key|
        arguments = { purpose: "credential_registration",
                      contact_ceremony_transaction_ref: uuid,
                      contact_otp_generation: uuid, }
        assert_raises(ArgumentError) {
          EmailCredentialRegistrationOtpDeliveryBindingValue.for(**arguments.merge(key => invalid))
        }
      end
    end
  end

  test "APP and COM candidate references retain one through twenty-one character boundaries" do
    %w(app com).each do |surface|
      ["a", "aa", "a" * 20, "a" * 21].each do |reference|
        value = TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
          otp_binding: [surface, "credential_registration", "12345678-1234-4000-8000-123456789abc",
                        reference, "87654321-4321-4000-b000-cba987654321",],
        )

        assert_equal reference, value.candidate_ref
      end
      [nil, "", "a" * 22, " ", "a b", "a/b", "a.b", "a\n", "é", "電話", "\xFF",
       "a".encode("UTF-16LE"), [], {}, 0, false,].each do |invalid|
        assert_raises(ArgumentError) do
          TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
            otp_binding: [surface, "credential_registration", "12345678-1234-4000-8000-123456789abc",
                          invalid, "87654321-4321-4000-b000-cba987654321",],
          )
        end
      end
    end
  end

  test "opaque UUID generation rejects every former decimal counter partition without counter arithmetic" do
    # Decimal counter bounds are superseded, not UUID arithmetic boundaries.
    ["0", "1", ((1 << 64) - 2).to_s, ((1 << 64) - 1).to_s,
     nil, "", "-1", (1 << 64).to_s, "00", "01", "+1", " 1", "1 ", "1\n", "1.0", "1e1", "０",
     0, 1, [], {}, false,].each do |invalid|
      assert_raises(ArgumentError) do
        TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
          otp_binding: ["com", "credential_registration", "12345678-1234-4000-8000-123456789abc", "contact", invalid],
        )
      end
      assert_raises(ArgumentError) do
        EmailCredentialRegistrationOtpDeliveryBindingValue.for(
          purpose: "credential_registration", contact_ceremony_transaction_ref: "12345678-1234-4000-8000-123456789abc",
          contact_otp_generation: invalid,
        )
      end
    end
  end

  test "Email registration requires complete typed transaction and generation metadata" do
    arguments = {
      purpose: "credential_registration",
      contact_ceremony_transaction_ref: "12345678-1234-4000-8000-123456789abc",
      contact_otp_generation: "87654321-4321-4000-b000-cba987654321",
    }
    value = EmailCredentialRegistrationOtpDeliveryBindingValue.for(**arguments)

    assert_equal arguments.except(:purpose), value.to_h
    arguments.each_key do |key|
      assert_raises(ArgumentError) { EmailCredentialRegistrationOtpDeliveryBindingValue.for(**arguments.except(key)) }
      assert_raises(ArgumentError) {
        EmailCredentialRegistrationOtpDeliveryBindingValue.for(**arguments.merge(key => nil))
      }
    end
  end

  test "other Email purposes return nil only when both registration metadata fields are nil" do
    [nil, "", "sign_in", "sign_up", "other"].each do |purpose|
      assert_nil EmailCredentialRegistrationOtpDeliveryBindingValue.for(
        purpose:, contact_ceremony_transaction_ref: nil, contact_otp_generation: nil,
      )
      [
        ["12345678-1234-4000-8000-123456789abc", nil],
        [nil, "87654321-4321-4000-b000-cba987654321"],
        ["12345678-1234-4000-8000-123456789abc", "87654321-4321-4000-b000-cba987654321"],
        ["", nil], [nil, ""], [[], nil], [nil, {}],
      ].each do |reference, generation|
        assert_raises(ArgumentError) do
          EmailCredentialRegistrationOtpDeliveryBindingValue.for(
            purpose:, contact_ceremony_transaction_ref: reference, contact_otp_generation: generation,
          )
        end
      end
    end
  end

  test "both channel bindings own immutable snapshots despite caller strings and exported container mutation" do
    tuple = [+"app", +"credential_registration", +"12345678-1234-4000-8000-123456789abc",
             +"contact", +"87654321-4321-4000-b000-cba987654321",]
    expected = tuple.map(&:dup)
    telephone = TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple)
    email = EmailCredentialRegistrationOtpDeliveryBindingValue.for(
      purpose: tuple[1], contact_ceremony_transaction_ref: tuple[2], contact_otp_generation: tuple[4],
    )
    tuple.each { |field| field.replace("changed") }
    exported = telephone.to_a
    exported[0] = "changed"
    parameters = email.to_h
    parameters[:contact_otp_generation] = "changed"

    assert_predicate telephone, :frozen?
    assert_predicate email, :frozen?
    assert_equal expected, telephone.to_a
    assert_equal({ contact_ceremony_transaction_ref: expected[2], contact_otp_generation: expected[4] }, email.to_h)
    [telephone.surface, telephone.purpose, telephone.transaction_ref, telephone.candidate_ref, telephone.generation,
     email.contact_ceremony_transaction_ref, email.contact_otp_generation,].each do |field|
      assert_raises(FrozenError) { field.replace("changed") }
    end
  end
end
