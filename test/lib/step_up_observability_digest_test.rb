# frozen_string_literal: true

require "test_helper"

class StepUpObservabilityDigestTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a ceremony reference is a stable 128-bit hex value that does not contain the identifier" do
    reference = StepUpObservabilityDigest.ceremony_ref("5f0c1b1e-0000-4000-8000-000000000001")

    assert_match(/\A[0-9a-f]{32}\z/, reference)
    assert_equal reference, StepUpObservabilityDigest.ceremony_ref("5f0c1b1e-0000-4000-8000-000000000001")
    assert_not_includes reference, "5f0c1b1e"
  end

  test "a reference cannot be recomputed with an unkeyed hash of the identifier" do
    identifier = "5f0c1b1e-0000-4000-8000-000000000001"

    assert_not_equal Digest::SHA256.hexdigest(identifier)[0, 32], StepUpObservabilityDigest.ceremony_ref(identifier)
  end

  test "the same identifier yields a different reference for each kind" do
    identifier = "shared-identifier"
    references = [
      StepUpObservabilityDigest.ceremony_ref(identifier),
      StepUpObservabilityDigest.session_ref(identifier),
      StepUpObservabilityDigest.jump_jti_ref(identifier),
    ]

    assert_equal 3, references.uniq.size
  end

  test "different identifiers yield different references" do
    assert_not_equal StepUpObservabilityDigest.session_ref("session-a"),
                     StepUpObservabilityDigest.session_ref("session-b")
  end

  # Sentinels of the String-typed interface: missing, empty, whitespace, and a non-String zero.
  [nil, "", "   ", 0].each do |identifier|
    test "a #{identifier.inspect} identifier is rejected instead of producing a shared reference" do
      assert_raises(ArgumentError) { StepUpObservabilityDigest.ceremony_ref(identifier) }
      assert_raises(ArgumentError) { StepUpObservabilityDigest.session_ref(identifier) }
      assert_raises(ArgumentError) { StepUpObservabilityDigest.jump_jti_ref(identifier) }
    end
  end

  test "an identifier containing a NUL character is digested without truncation at the NUL" do
    assert_not_equal StepUpObservabilityDigest.ceremony_ref("abc\u0000def"),
                     StepUpObservabilityDigest.ceremony_ref("abc")
  end
end
