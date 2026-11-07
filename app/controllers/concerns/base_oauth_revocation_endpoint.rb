# typed: false
# frozen_string_literal: true

module BaseOauthRevocationEndpoint
  class InvalidRequest < StandardError; end

  FIELDS = %w(
    token client_id client_secret token_type_hint client_assertion_type client_assertion
  ).freeze
  private_constant :FIELDS

  private

  # Runs after the source-IP guard. Authentication is cached on this per-request operation instance
  # so the client-keyed limiter can use the authenticated id without consuming an assertion twice.
  def prepare_revocation_request!(resource_type:)
    @revoker = ::OidcTokenRevoker.new(
      **revocation_request_arguments,
      host: request.host,
      expected_resource_type: resource_type,
      revocation_endpoint_uri: ::OidcIssuer.revocation_endpoint(resource_type),
    )
    @authenticated_revocation_client_id = @revoker.authenticated_client_id
  end

  def authenticated_revocation_client?
    @authenticated_revocation_client_id.present?
  end

  def authenticated_revocation_client_id
    @authenticated_revocation_client_id
  end

  def revocation_request_arguments
    if (request.query_parameters.keys & FIELDS).any?
      raise InvalidRequest, "revocation credentials belong in the request body"
    end

    body = request.request_parameters.slice(*FIELDS)
    unless body.values.all?(String)
      raise InvalidRequest, "revocation fields must be scalar strings"
    end
    raise InvalidRequest, "revocation token is required" if body["token"].blank?

    FIELDS.to_h { |field| [field.to_sym, body[field]] }
  end

  def render_revocation_result(result)
    return head(:ok) if result.success?

    render json: { error: result.error, error_description: result.error_description },
           status: :unauthorized
  end

  def render_revocation_invalid_request
    render json: { error: "invalid_request" }, status: :bad_request
  end

  def render_revocation_dependency_failure(error)
    Rails.logger.error(
      ::JitLogEvent.format("oidc.revocation.dependency_unavailable", error_class: error.class.name),
    )
    render json: { error: "temporarily_unavailable" }, status: :service_unavailable
  end
end
