# frozen_string_literal: true

require "test_helper"

class OrgIamRequestDigestTest < ActiveSupport::TestCase
  test "grant identity binds all behavior-affecting inputs" do
    inputs = {
      actor_public_id: "actor",
      subject_public_id: "subject",
      capability: "read",
      duration_seconds: 600,
      reason_code: "reason",
      ticket_id: "ticket",
    }
    digest = OrgIamRequestDigest.grant(**inputs)

    assert_match(/\A[0-9a-f]{64}\z/, digest)
    assert_equal digest, OrgIamRequestDigest.grant(**inputs)
    inputs.each do |key, value|
      changed = (key == :duration_seconds) ? value + 1 : "different"

      assert_not_equal digest, OrgIamRequestDigest.grant(**inputs.merge(key => changed)), key.to_s
    end
    assert_not_equal digest, OrgIamRequestDigest.grant(**inputs.merge(ticket_id: nil))
    assert_raises(ArgumentError) { OrgIamRequestDigest.grant(**inputs.merge(duration_seconds: 0)) }
    assert_raises(ArgumentError) { OrgIamRequestDigest.grant(**inputs.merge(actor_public_id: "")) }
    assert_raises(ArgumentError) { OrgIamRequestDigest.grant(**inputs.merge(ticket_id: "")) }
  end

  test "revocation identity binds the grant and is separate from grant identity" do
    inputs = { actor_public_id: "actor", subject_public_id: "subject", grant_public_id: "grant", reason_code: "reason" }
    digest = OrgIamRequestDigest.revoke(**inputs)

    assert_equal digest, OrgIamRequestDigest.revoke(**inputs)
    assert_not_equal digest, OrgIamRequestDigest.grant(
      actor_public_id: "actor", subject_public_id: "subject", capability: "grant", duration_seconds: 1,
      reason_code: "reason", ticket_id: nil,
    )
    inputs.each_key do |key|
      assert_not_equal digest, OrgIamRequestDigest.revoke(**inputs.merge(key => "different")), key.to_s
    end
    assert_raises(ArgumentError) { OrgIamRequestDigest.revoke(**inputs.merge(grant_public_id: "")) }
  end
end
