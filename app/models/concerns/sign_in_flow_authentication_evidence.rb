# frozen_string_literal: true

# Included by the concrete sign-in flows. Authentication evidence belongs to the flow's writer
# database; Base reads it at the final issuance boundary.
module SignInFlowAuthenticationEvidence
  public

  def record_authentication_evidence!(method:, authenticated_at: nil,
                                      authentication_context: AuthenticationContextValue::NORMAL_KEY)
    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        raise AuthCeremonySession::InvalidTransition, "sign-in flow is expired" if expired?(now)
        unless (state_name_for(state_id) == "PRIMARY_PENDING" && sign_in_primary_pending?) ||
            (state_name_for(state_id) == "MFA_PENDING" && sign_in_mfa_pending?)
          raise AuthCeremonySession::InvalidTransition, "sign-in flow cannot accept authentication evidence"
        end
        raise AuthCeremonySession::InvalidTransition, "sign-in flow has no principal" if principal_id.nil?
        raise AuthCeremonySession::InvalidTransition,
              "authentication evidence is already recorded" if authentication_event_at
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
end
