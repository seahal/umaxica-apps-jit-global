# frozen_string_literal: true

# Included by the concrete sign-in flows. Evidence and result generations belong to the
# existing flow's writer database; the opaque transport never owns the final issuance decision.
module LocalAuthenticationResultDelivery
  public

  def record_local_authentication_evidence!(method:, authenticated_at: nil,
                                            authentication_context: AuthenticationContextValue::NORMAL_KEY)
    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        raise AuthCeremonySession::InvalidTransition, "local flow is expired" if expired?(now)
        unless (state_name_for(state_id) == "PRIMARY_PENDING" && sign_in_primary_pending?) ||
            (state_name_for(state_id) == "MFA_PENDING" && sign_in_mfa_pending?)
          raise AuthCeremonySession::InvalidTransition, "local flow cannot accept authentication evidence"
        end
        raise AuthCeremonySession::InvalidTransition, "local flow has no principal" if principal_id.nil?
        raise AuthCeremonySession::InvalidTransition, "local evidence is already recorded" if authentication_event_at
        unless AuthCeremonySession::AUTHENTICATION_METHODS.include?(method.to_s)
          raise AuthCeremonySession::InvalidTransition, "unsupported authentication method"
        end
        unless AuthenticationContextValue::KEYS.include?(authentication_context)
          raise AuthCeremonySession::InvalidTransition, "unsupported authentication context"
        end

        event_at = authenticated_at || now
        raise AuthCeremonySession::InvalidTransition, "authentication time is in the future" if event_at > now

        update!(
          authentication_method: method.to_s, authentication_event_at: event_at,
          authentication_context: authentication_context,
        )
      end
    end
  end

  def prepare_local_result_delivery!(digest:, ttl:)
    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        unless state_name_for(state_id) == "SESSION_ISSUANCE_PENDING"
          raise AuthCeremonySession::InvalidTransition, "local flow is not ready for result delivery"
        end
        raise AuthCeremonySession::InvalidTransition, "local flow is expired" if expired?(now)
        raise AuthCeremonySession::InvalidTransition, "local flow is finalized" if base_finalized_at
        raise AuthCeremonySession::InvalidTransition, "local evidence is missing" unless authentication_event_at
        raise ArgumentError, "invalid result digest" unless digest.is_a?(String) && digest.match?(/\A[0-9a-f]{64}\z/)
        raise ArgumentError, "result TTL must be positive" unless ttl.positive?

        update!(
          result_digest: digest, result_generation: result_generation + 1,
          result_expires_at: [now + ttl, expires_at].min,
        )
        result_generation
      end
    end
  end

  def local_result_delivery_matches?(digest:, generation:, now: nil)
    now ||= self.class.database_now
    return false unless digest.is_a?(String) && digest.match?(/\A[0-9a-f]{64}\z/)
    return false unless generation.is_a?(Integer) && generation.positive?
    return false unless result_digest && result_expires_at && result_expires_at > now && !expired?(now)

    result_generation == generation && ActiveSupport::SecurityUtils.secure_compare(result_digest, digest)
  end
end
