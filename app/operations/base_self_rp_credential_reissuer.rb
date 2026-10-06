# frozen_string_literal: true

# Reissues the initiating Base self-RP credentials after a committed ceremony. The root token is
# intentionally outside this operation for ordinary step-up: only the RP Session's OIDC claims
# change, and the shared OIDC token authority performs rotation and delivery coalescing.
class BaseSelfRpCredentialReissuer
  class CredentialUnavailable < StandardError; end

  class DependencyError < StandardError; end

  class << self
    public

    def refreshable?(resource:, rp_session:, raw_refresh_token:, client_id:)
      resolved = resolve!(
        resource:, rp_session:, raw_refresh_token:, client_id:,
      )
      resolved.present?
    rescue CredentialUnavailable
      false
    end

    def call!(resource:, rp_session:, raw_refresh_token:, client_id:, authentication_event_at:, acr:, amr:)
      raise ArgumentError, "authentication event time is required" unless authentication_event_at.respond_to?(:to_time)
      raise ArgumentError, "RP authentication method evidence is required" if Array(amr).blank?

      resolved = resolve!(
        resource:, rp_session:, raw_refresh_token:, client_id:,
      )
      update_claims!(usage: resolved.usage, verifier: resolved.verifier, authentication_event_at:, acr:, amr:) if
        current_refresh_credential?(usage: resolved.usage, verifier: resolved.verifier)

      resource_type = resource_type_for(rp_session)
      token_endpoint_uri = OidcIssuer.token_endpoint(resource_type)
      client_assertion = OidcClientAssertionJwt.issue(
        client_id: client_id, token_url: token_endpoint_uri,
      )
      raise DependencyError, "Base self-RP client assertion unavailable" if client_assertion.blank?

      result = OidcTokenExchangeCoordinator.call(
        grant_type: "refresh_token", refresh_token: raw_refresh_token, client_id: client_id,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion:, token_endpoint_uri:, request_method: "POST", expected_resource_type: resource_type,
      )
      return result if result.success?

      if result.error.to_s.in?(%w(server_error temporarily_unavailable))
        raise DependencyError, "Base self-RP credential delivery unavailable"
      end

      raise CredentialUnavailable, "Base self-RP refresh credential is no longer usable"
    rescue ActiveRecord::ActiveRecordError, Umaxica::Valkey::Unavailable,
           Umaxica::Valkey::SerializationError, Umaxica::Valkey::OperationError => e
      raise DependencyError, "Base self-RP credential dependency unavailable", cause: e
    end

    private

    def resolve!(resource:, rp_session:, raw_refresh_token:, client_id:)
      raise CredentialUnavailable, "Base self-RP refresh credential is missing" unless
        raw_refresh_token.is_a?(String) && raw_refresh_token.present? && raw_refresh_token == raw_refresh_token.strip
      raise CredentialUnavailable, "Base self-RP Session is unavailable" unless
        rp_session && rp_session.oidc_client_id == client_id

      resource_type = resource_type_for(rp_session)
      resolved = OidcRefreshTokenIssuer.resolve(
        refresh_token: raw_refresh_token, resource_type: resource_type,
      )
      raise CredentialUnavailable, "Base self-RP refresh credential is invalid" unless resolved

      usage = resolved.usage
      root_token = usage.parent_token
      device_session = usage.parent_device_session
      unless usage.public_id == rp_session.public_id && usage.oidc_client_id == client_id && usage.active? &&
          device_session&.usable? && device_session.current_refresh_token_id == root_token&.id &&
          root_token&.currently_usable? && resource_matches?(root_token, resource)
        raise CredentialUnavailable, "Base self-RP authority is unavailable"
      end
      unless current_refresh_credential?(usage:, verifier: resolved.verifier) ||
          delivery_replay_credential?(usage:, verifier: resolved.verifier)
        raise CredentialUnavailable, "Base self-RP refresh credential is stale"
      end

      resolved
    end

    def current_refresh_credential?(usage:, verifier:)
      usage.refresh_token_digest_matches?(verifier)
    end

    def delivery_replay_credential?(usage:, verifier:)
      usage.previous_refresh_token_digest_matches?(verifier) && usage.refresh_delivery_receipt_present?
    end

    def update_claims!(usage:, verifier:, authentication_event_at:, acr:, amr:)
      owner = usage.class.connection_class_for_self
      owner.connected_to(role: :writing) do
        usage.class.transaction do
          locked = usage.class.lock.find(usage.id)
          unless locked.active? && locked.refresh_token_digest_matches?(verifier)
            raise CredentialUnavailable, "Base self-RP refresh credential changed"
          end

          locked.update!(
            oidc_auth_time: authentication_event_at,
            oidc_acr: acr.to_s.presence,
            oidc_amr: JSON.generate(Array(amr).map(&:to_s)),
          )
        end
      end
    end

    def resource_type_for(rp_session)
      case rp_session
      when ClientRpSession then "client"
      when VisitorRpSession then "visitor"
      when OperatorRpSession then "operator"
      else raise CredentialUnavailable, "unsupported Base self-RP Session"
      end
    end

    def resource_matches?(root_token, resource)
      case root_token
      when ClientToken then root_token.user_id == resource.id && resource.is_a?(Client)
      when VisitorToken then root_token.visitor_id == resource.id && resource.is_a?(Visitor)
      when OperatorToken then root_token.staff_id == resource.id && resource.is_a?(Operator)
      else false
      end
    end
  end
end
