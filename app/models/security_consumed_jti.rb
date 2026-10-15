# typed: false
# frozen_string_literal: true

class SecurityConsumedJti < AppTicketRecord
  PURPOSES = {
    oidc_logout_request: "oidc_logout_request",
    oidc_client_assertion: "oidc_client_assertion",
    sign_out_notice: "sign_out_notice",
  }.freeze

  class << self
    def consume!(purpose:, issuer:, jti:, expires_at:)
      return false if purpose.to_s.blank? || issuer.to_s.blank? || jti.to_s.blank?

      # A replay record is always a write, also when the caller is serving a safe request on the
      # reading role.
      connection_class_for_self.connected_to(role: :writing) do
        create!(
          purpose: purpose.to_s,
          issuer: issuer.to_s,
          jti_digest: digest_jti(jti),
          expires_at: expires_at,
        )
      end
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end

    def digest_jti(jti)
      Digest::SHA256.hexdigest(jti.to_s)
    end
  end
end
