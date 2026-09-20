# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch9SessionsAndZerosTest < ActiveSupport::TestCase
  test "zero-percent ceremony results reject future verified_at" do
    now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    specs = [
      [IdentityEmailCeremonyResult, IdentityEmailCeremonyContract, "registration", {}],
      [IdentityTelephoneCeremonyResult, IdentityTelephoneCeremonyContract, "registration", {}],
      [IdentityPasskeyCeremonyResult, IdentityPasskeyCeremonyContract, "registration",
       { "webauthn_id" => "w", "public_key" => "pk", "sign_count" => 0 },],
      [IdentityTotpCeremonyResult, IdentityTotpCeremonyContract, "registration",
       { "credential_candidate_ref" => "r", "credential_candidate_digest" => "d" },],
      [IdentitySecretCredentialCeremonyResult, IdentitySecretCredentialCeremonyContract, "enrollment",
       { "credential_candidate_ref" => "r", "credential_candidate_digest" => "d" },],
    ]
    specs.each do |klass, contract, operation, extra|
      future = now + contract::LEEWAY + 120
      payload = {
        "typ" => klass::TOKEN_TYPE,
        "iss" => contract.sign_issuer("app"),
        "aud" => contract.acme_audience("app"),
        "purpose" => klass::PURPOSE,
        "surface" => "app",
        "actor_ref" => "a",
        "session_ref" => "s",
        "transaction_id" => "t",
        "grant_jti" => "g",
        "result_jti" => "r",
        "operation" => operation,
        "proof_method" => klass::PROOF_METHOD,
        "verified_at" => future.to_i,
        "challenge_id" => "c",
        "expires_at" => (now + 5.minutes).to_i,
        "iat" => now.to_i,
        "exp" => (now + 5.minutes).to_i,
      }.merge(extra)
      error_class =
        if klass == IdentityTelephoneCeremonyResult
          IdentityTelephoneCeremony::Error
        else
          contract::Error
        end
      err = assert_raises(error_class) { klass.new(payload, now: now) }
      assert_match(/verified_at must not be in the future/, err.message)
    end
  end

  test "group and membership service early returns" do
    group = Object.new
    group.define_singleton_method(:archived?) { true }

    assert_same group, GroupManagement::Archive.new(group: group).call

    membership = Object.new
    membership.define_singleton_method(:active?) { false }

    assert_same membership, GroupAvatarMemberships::Detach.new(membership: membership).call

    membership2 = Object.new
    membership2.define_singleton_method(:revoked?) { true }
    assert_raises(CollectiveMembership::InactiveMembership) do
      CollectiveMembership::Suspend.new(membership: membership2).call
    end

    membership3 = Object.new
    membership3.define_singleton_method(:active?) { false }
    assert_raises(CollectiveMembership::InactiveMembership) do
      CollectiveMembership::MakePrimary.new(membership: membership3).call
    end
  end

  test "SecurityConsumedJti and SessionLimitResolutionTokenRef blank guards" do
    assert_not SecurityConsumedJti.consume!(purpose: "", issuer: "x", jti: "y", expires_at: 1.hour.from_now)
    assert_nil SessionLimitResolutionTokenRef.find_client_token("")
  end
end
