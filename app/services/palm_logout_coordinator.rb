# typed: false
# frozen_string_literal: true

class PalmLogoutCoordinator < ApplicationService
  Result =
    Data.define(
      :success, :logout_url, :state, :expires_at, :transaction, :resource, :token, :error,
      :error_description,
    ) do
      def success? = success
    end

  def self.call(...) = new(...).call

  def initialize(request:, ri: nil)
    super()
    @request = request
    @ri = ri
  end

  def call
    authentication_result = authenticate_current_token
    return failure(
      authentication_result[:error],
      authentication_result[:error_description],
    ) unless authentication_result[:success]

    resource = authentication_result[:resource]
    token = authentication_result[:token]
    state = SecureRandom.urlsafe_base64(24)

    transaction_result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "palm",
      initiating_client_id: AuthorizationTokenClaims.client_id(authentication_result[:payload]).presence ||
        "app-ios-rp",
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(origin_surface: "palm"),
      actor_ref: resource.public_id,
      session_ref: token.public_id,
      callback_state: state,
    )
    return failure(transaction_result.error, transaction_result.error_description) unless transaction_result.success?

    transaction = transaction_result.transaction
    rt = JumpRtIssuer.call(
      namespace: "PALM_APP",
      url: acme_oidc_logout_url(logout_challenge: transaction.logout_challenge),
    )
    return failure("invalid_request", "logout Jump token could not be issued") if rt.blank?

    gateway = RedirectsJumpGatewayUrl.call(rt)
    return failure("invalid_request", "logout Jump gateway is unavailable") unless gateway.ok?

    AuthenticationLogoutCurrentSession.call(
      current: Actor,
      resource: resource,
      token: token,
      token_class: ClientToken,
      session_public_id: token.public_id,
      reason: "user_logout",
    )
    revoke_refresh_token_family!(token)
    AcmeLogoutTransactionCoordinator.advance!(
      logout_challenge: transaction.logout_challenge,
      step: AcmeLogoutTransaction::STEP_ORIGIN_CLEARED,
    )

    Result.new(
      success: true,
      logout_url: gateway.value,
      state: state,
      expires_at: transaction.expires_at,
      transaction: transaction,
      resource: resource,
      token: token,
      error: nil,
      error_description: nil,
    )
  end

  private

  attr_reader :request, :ri

  def authenticate_current_token
    auth_result = PalmAccessTokenAuthenticator.call(
      access_token: authorization_access_token,
      host: request.host,
      authorization_scheme: authorization_scheme,
    )
    return { success: false,
             error: auth_result.error,
             error_description: "authentication failed", } unless auth_result.success?

    token = ClientToken.find_by(
      oidc_sid: auth_result.payload["sid"].to_s,
      oidc_jti: auth_result.payload["jti"].to_s,
      oidc_client_id: AuthorizationTokenClaims.client_id(auth_result.payload).to_s,
    )
    return { success: false,
             error: "invalid_token",
             error_description: "logout token not found",
             payload: auth_result.payload, } if token.blank?
    return { success: false,
             error: "invalid_token",
             error_description: "logout token is not active",
             payload: auth_result.payload, } unless token.active?

    {
      success: true,
      payload: auth_result.payload,
      resource: auth_result.resource,
      token: token,
    }
  end

  def authorization_access_token
    AuthAuthorizationHeader.access_token(request)
  end

  def authorization_scheme
    request.authorization.to_s.split(/\s+/, 2).first
  end

  def acme_oidc_logout_url(**query)
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    Rails.application.routes.url_helpers.base_app_oidc_logout_url(
      host: host,
      protocol: "https",
      ri: ri || RequestContextContract.default_region,
      **query,
    )
  end

  def revoke_refresh_token_family!(token)
    family_id = token.refresh_token_family_id.to_s
    now = Time.current

    ClientToken.transaction do
      token.lock!
      scope =
        if family_id.present?
          ClientToken.where(refresh_token_family_id: family_id)
        else
          ClientToken.where(id: token.id)
        end

      # rubocop:disable Rails/SkipsModelValidations
      scope.update_all(discard_at: now, updated_at: now)
      ClientDeviceSession.where(refresh_token_family_id: family_id).update_all(
        revoked_at: now,
        updated_at: now,
      ) if family_id.present?
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def failure(error, error_description)
    Result.new(
      success: false,
      logout_url: nil,
      state: nil,
      expires_at: nil,
      transaction: nil,
      resource: nil,
      token: nil,
      error: error,
      error_description: error_description,
    )
  end
end
