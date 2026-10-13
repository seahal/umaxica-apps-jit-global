# frozen_string_literal: true

require "test_helper"

class CredentialRegistrationOtpSessionValueTest < ActiveSupport::TestCase
  test "registration session encodes the original Root and realm channel transaction bound browser digest" do
    arguments = {
      surface: "app",
      channel: :email,
      transaction_ref: SecureRandom.uuid,
      root_ref: "original-root",
      browser_nonce: SecureRandom.urlsafe_base64(32),
    }
    binding = CredentialRegistrationOtpSessionValue.for(**arguments)
    parsed = JSON.parse(binding.dump)

    assert_equal [1, arguments.fetch(:root_ref), binding.browser_digest], parsed
    assert_equal binding, CredentialRegistrationOtpSessionValue.load(session_ref: binding.dump)
    assert_predicate binding, :frozen?
    assert_not_includes binding.dump, arguments.fetch(:browser_nonce)
    assert_not_includes binding.inspect, binding.browser_digest
    [arguments.merge(surface: "com"), arguments.merge(surface: "org"),
     arguments.merge(channel: :telephone), arguments.merge(transaction_ref: SecureRandom.uuid),
     arguments.merge(root_ref: "different-root"),
     arguments.merge(browser_nonce: SecureRandom.urlsafe_base64(32)),].each do |foreign|
      assert_not_equal binding.browser_digest, CredentialRegistrationOtpSessionValue.for(**foreign).browser_digest
    end
  end

  test "registration session accepts an issued NanoID transaction reference" do
    binding = CredentialRegistrationOtpSessionValue.for(
      surface: "app", channel: :email, transaction_ref: "A1_b2-C3d4E5f6G7h8I9j",
      root_ref: "original-root", browser_nonce: SecureRandom.urlsafe_base64(32),
    )

    assert_predicate binding, :frozen?
  end

  test "registration session rejects typed malformed NUL and length neighbors without plain Root fallback" do
    arguments = {
      surface: "app",
      channel: :email,
      transaction_ref: SecureRandom.uuid,
      root_ref: "original-root",
      browser_nonce: SecureRandom.urlsafe_base64(32),
    }

    [nil, false, 0, "", "a" * 22, "r\0oot", "\xFF", "root".encode(Encoding::UTF_16LE)].each do |bad|
      assert_raises(ArgumentError) { CredentialRegistrationOtpSessionValue.for(**arguments.merge(root_ref: bad)) }
    end
    ["r", "r" * 21].each do |accepted|
      assert_equal accepted, CredentialRegistrationOtpSessionValue.for(**arguments.merge(root_ref: accepted)).root_ref
    end
    nonce = arguments.fetch(:browser_nonce)

    [nil, "", false, 0, nonce[0...-1], "#{nonce}x", "#{nonce}\0"].each do |bad|
      assert_raises(ArgumentError) { CredentialRegistrationOtpSessionValue.for(**arguments.merge(browser_nonce: bad)) }
    end
    [arguments.merge(surface: "unknown"), arguments.merge(channel: :unknown),
     arguments.merge(transaction_ref: nil), arguments.merge(transaction_ref: ""),
     arguments.merge(transaction_ref: arguments.fetch(:transaction_ref)[0...-1]),
     arguments.merge(transaction_ref: "#{arguments.fetch(:transaction_ref)}x"),].each do |bad|
      assert_raises(ArgumentError) { CredentialRegistrationOtpSessionValue.for(**bad) }
    end
    [nil, "", 0, false, "original-root", "[]", "[1,\"root\"]", "[1,\"root\",\"invalid\"]",
     JSON.generate([1.0, "root", "a" * 64]), JSON.generate([1, "root", "a" * 63]),
     JSON.generate([1, "root", "a" * 65]), JSON.generate([1, "root", "a" * 64, "extra"]),].each do |bad|
      assert_raises(ArgumentError) { CredentialRegistrationOtpSessionValue.load(session_ref: bad) }
    end
  end
end
