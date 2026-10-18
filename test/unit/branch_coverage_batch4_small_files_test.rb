# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch4SmallFilesTest < ActiveSupport::TestCase
  test "identity ceremony results reject future verified_at for email" do
    now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    future = now + IdentityEmailCeremonyContract::LEEWAY + 120
    payload = {
      "typ" => IdentityEmailCeremonyResult::TOKEN_TYPE,
      "iss" => IdentityEmailCeremonyContract.sign_issuer("app"),
      "aud" => IdentityEmailCeremonyContract.acme_audience("app"),
      "purpose" => IdentityEmailCeremonyResult::PURPOSE,
      "surface" => "app",
      "actor_ref" => "a",
      "session_ref" => "s",
      "transaction_id" => "t",
      "grant_jti" => "g",
      "result_jti" => "r",
      "operation" => "registration",
      "proof_method" => IdentityEmailCeremonyResult::PROOF_METHOD,
      "email_digest" => "digest",
      "verified_at" => future.to_i,
      "challenge_id" => "c",
      "expires_at" => (now + 5.minutes).to_i,
      "iat" => now.to_i,
      "exp" => (now + 5.minutes).to_i,
    }
    assert_raises(IdentityEmailCeremonyContract::Error) do
      IdentityEmailCeremonyResult.new(payload, now: now)
    end
  end
end
