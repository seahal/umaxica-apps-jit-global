# frozen_string_literal: true

require "test_helper"

class StepUpPkceVerifierCipherAdapterTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  test "encrypt and decrypt round-trip a valid PKCE verifier without storing it in plaintext" do
    verifier = "a" * 43

    ciphertext = StepUpPkceVerifierCipherAdapter.encrypt(verifier:)

    assert_equal verifier, StepUpPkceVerifierCipherAdapter.decrypt(ciphertext:)
    assert_not_includes ciphertext, verifier
  end

  test "rejects missing empty malformed and out-of-range verifiers" do
    [nil, "", "a" * 42, "a" * 129, ("a" * 42) + "%"].each do |verifier|
      assert_raises(ArgumentError) { StepUpPkceVerifierCipherAdapter.encrypt(verifier:) }
    end
  end

  test "rejects tampered ciphertext and the destroyed-verifier sentinel" do
    ciphertext = StepUpPkceVerifierCipherAdapter.encrypt(verifier: "b" * 43)
    tampered = ciphertext.sub(/\A./) { |first| (first == "x") ? "y" : "x" }

    assert_raises(StepUpPkceVerifierCipherAdapter::InvalidCiphertext) do
      StepUpPkceVerifierCipherAdapter.decrypt(ciphertext: tampered)
    end
    assert_raises(StepUpPkceVerifierCipherAdapter::InvalidCiphertext) do
      StepUpPkceVerifierCipherAdapter.decrypt(ciphertext: StepUpPkceVerifierCipherAdapter.destroyed_ciphertext)
    end
  end
end
