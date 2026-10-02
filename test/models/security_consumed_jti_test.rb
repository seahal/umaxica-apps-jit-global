# typed: false
# frozen_string_literal: true

require "test_helper"

class SecurityConsumedJtiTest < ActiveSupport::TestCase
  test "consume records first jti and rejects duplicate purpose issuer jti" do
    jti = SecureRandom.uuid

    assert SecurityConsumedJti.consume!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_logout_request),
      issuer: "issuer-a",
      jti: jti,
      expires_at: 2.minutes.from_now,
    )
    assert_not SecurityConsumedJti.consume!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_logout_request),
      issuer: "issuer-a",
      jti: jti,
      expires_at: 2.minutes.from_now,
    )
  end

  test "same jti under different purpose does not collide" do
    jti = SecureRandom.uuid

    assert SecurityConsumedJti.consume!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_logout_request),
      issuer: "issuer-a",
      jti: jti,
      expires_at: 2.minutes.from_now,
    )
    assert SecurityConsumedJti.consume!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:sign_out_notice),
      issuer: "issuer-a",
      jti: jti,
      expires_at: 2.minutes.from_now,
    )
  end

  test "same jti under different issuer does not collide" do
    jti = SecureRandom.uuid

    assert SecurityConsumedJti.consume!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_logout_token),
      issuer: "issuer-a",
      jti: jti,
      expires_at: 2.minutes.from_now,
    )
    assert SecurityConsumedJti.consume!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_logout_token),
      issuer: "issuer-b",
      jti: jti,
      expires_at: 2.minutes.from_now,
    )
  end

  test "stores digest rather than raw jti" do
    jti = "raw-jti-value"

    assert SecurityConsumedJti.consume!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_logout_request),
      issuer: "issuer-a",
      jti: jti,
      expires_at: 2.minutes.from_now,
    )

    record = SecurityConsumedJti.find_by!(purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_logout_request))

    assert_equal Digest::SHA256.hexdigest(jti), record.jti_digest
    assert_not_equal jti, record.jti_digest
  end
end
