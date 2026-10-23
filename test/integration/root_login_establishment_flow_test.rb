# typed: false
# frozen_string_literal: true

require "test_helper"

# Root issuance HTTP checks through the real middleware and databases. Each case checks what the database, the cookies, the next request, and the audit say -- not only the
# response code (adr/root-login-establishment-boundary.md).
class RootLoginEstablishmentFlowTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses

  setup do
    clear_enqueued_jobs
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    ClientSignInFlowState::DEFAULTS.each { |id| ClientSignInFlowState.find_or_create_by!(id: id) }
    VisitorSignInFlowState::DEFAULTS.each { |id| VisitorSignInFlowState.find_or_create_by!(id: id) }
    ClientSessionLimitResolutionState::DEFAULTS.each do |id|
      ClientSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = Time.current
        state.updated_at = Time.current
      end
    end
    ClientSignOutFlowKind::DEFAULTS.each { |id| ClientSignOutFlowKind.find_or_create_by!(id: id) }
    ClientSignOutFlowStatus::DEFAULTS.each { |id| ClientSignOutFlowStatus.find_or_create_by!(id: id) }
    ClientIdentityState::DEFAULTS.each { |id| ClientIdentityState.find_or_create_by!(id: id) }
    VisitorIdentityState::DEFAULTS.each { |id| VisitorIdentityState.find_or_create_by!(id: id) }
    VisitorSecretCredentialKind::DEFAULTS.each { |id| VisitorSecretCredentialKind.find_or_create_by!(id: id) }
    VisitorSecretCredentialStatus::DEFAULTS.each { |id| VisitorSecretCredentialStatus.find_or_create_by!(id: id) }
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @user = clients(:one)
    ClientToken.where(user_id: @user.id).delete_all
    @email = @user.client_emails.create!(
      address: "root_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, binding_finalized_at: Time.current,
    )
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "a principal id in the session alone does not open session-limit management" do
    Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(authentication_epoch: 0, user: @user) }
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get base_app_sign_in_limitation_path, params: { ri: "jp", principal_id: @user.id, actor_ref: @user.public_id }

    assert_response :gone
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal ClientToken::MAX_SESSIONS_PER_USER, ClientToken.where(user_id: @user.id).count
  end

  test "a legacy RESTRICTED token does not authenticate even with a valid access token" do
    legacy = ClientToken.create!(authentication_epoch: 0, user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! base_host
    https!
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    access_token = AuthenticationToken.encode(
      @user, host: base_host, session_public_id: legacy.public_id, resource_type: "client",
             jwt_issuer_id: issuer.id,
    )
    source_before = @email.reload.attributes
    token_before = legacy.reload.attributes
    client = OidcClientRegistry.find!("base-app-ww")
    callback = client.redirect_uris.find { |uri| URI.parse(uri).host == base_host }

    assert_not_nil callback
    # The public landing page is not an authorization decision. Test the protected
    # OP SSO operation instead: a historical status-103 Root cannot produce an authorization code.
    state = SecureRandom.urlsafe_base64(32)
    assert_no_difference(["ClientToken.count", "OpAppGrant.count", "ClientChronicle.count"]) do
      get "/oauth/authorize", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: callback,
        scope: "openid profile",
        state: state,
        nonce: SecureRandom.urlsafe_base64(32),
        code_challenge: Base64.urlsafe_encode64(
          Digest::SHA256.digest(SecureRandom.urlsafe_base64(48)),
          padding: false,
        ),
        code_challenge_method: "S256",
        prompt: "none",
        ri: "jp",
      }, headers: { "Authorization" => "Bearer #{access_token}" }
    end

    assert_response :found
    callback_response = URI.parse(response.location)
    callback_query = Rack::Utils.parse_nested_query(callback_response.query)

    assert_equal URI.parse(callback).host, callback_response.host
    assert_equal URI.parse(callback).path, callback_response.path
    assert_equal "login_required", callback_query.fetch("error")
    assert_equal state, callback_query.fetch("state")
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_nil cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_nil cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    assert_withheld("Rejected SSO must not rewrite Source") { @email.reload.attributes == source_before }
    assert_withheld("Rejected SSO must not change the restricted Root") { legacy.reload.attributes == token_before }
  end
end
