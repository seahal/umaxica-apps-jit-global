# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyResultIssuer
  def self.issue!(surface:, actor_ref:, session_ref:, transaction_id:, grant_jti:, scope:, aal:, method:,
                  phishing_resistant: false, user_verified: false, full_reauthentication: false,
                  credential_ref:, resource_ref: nil, tenant_ref: nil, challenge_id:, expires_at:,
                  attempt_count: nil, now: Time.current)
    IdentityStepUpCeremonyResult.issue(
      {
        "surface" => surface.to_s,
        "actor_ref" => actor_ref.to_s,
        "session_ref" => session_ref.to_s,
        "transaction_id" => transaction_id.to_s,
        "grant_jti" => grant_jti.to_s,
        "result_jti" => SecureRandom.uuid,
        "scope" => scope.to_s,
        "aal" => aal.to_s,
        "phishing_resistant" => phishing_resistant,
        "user_verified" => user_verified,
        "full_reauthentication" => full_reauthentication,
        "credential_ref" => credential_ref.to_s,
        "resource_ref" => resource_ref,
        "tenant_ref" => tenant_ref,
        "method" => method.to_s,
        "verified_at" => now.to_i,
        "challenge_id" => challenge_id.to_s,
        "expires_at" => expires_at.to_i,
        "attempt_count" => attempt_count,
      }.compact,
      issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id(surface),
      now: now,
    )
  end
end
