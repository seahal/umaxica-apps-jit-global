# typed: false
# frozen_string_literal: true

class SecurityConsumedJti < AppTicketRecord
  PURPOSES = {
    oidc_logout_request: "oidc_logout_request",
    oidc_logout_token: "oidc_logout_token",
    jump_rt_return: "jump_rt_return",
    oidc_client_assertion: "oidc_client_assertion",
    sign_out_notice: "sign_out_notice",
  }.freeze

  class << self
    def consume!(purpose:, issuer:, jti:, expires_at:)
      return false if purpose.to_s.blank? || issuer.to_s.blank? || jti.to_s.blank?

      create!(
        purpose: purpose.to_s,
        issuer: issuer.to_s,
        jti_digest: digest_jti(jti),
        expires_at: expires_at,
      )
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end

    def digest_jti(jti)
      Digest::SHA256.hexdigest(jti.to_s)
    end
  end
end
