# typed: false
# frozen_string_literal: true

require "test_helper"

# A browser that abandoned an earlier OIDC sign-in still holds that attempt's sign-in flow locator.
# Redeeming a new admission starts a new path at its first page, so the clean first-page request
# must render instead of resuming the old flow and refusing the page as stale.
class SignInAdmissionStaleFlowTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  self.fixture_table_names = []

  test "a new admission renders the first page although an earlier attempt's live flow is in the session" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host!(auth_host)
    https!
    issuance = issue_sign_in_handoff
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    get(response.location, headers: NAVIGATION_HEADERS)
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)

    # The earlier attempt authenticated a principal but issued no session: the state an abandoned
    # MFA step leaves behind.
    flow_nonce = SecureRandom.urlsafe_base64(32)
    now = ClientSignInFlow.database_now
    stale_flow = ClientSignInFlow.create!(
      principal_id: 1, state_id: ClientSignInFlow.state_id_for("MFA_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(flow_nonce), issued_at: now, expires_at: now + 5.minutes,
    )
    install_session_values(
      auth_host, "app_sign_in_flow_locator" => { "public_id" => stale_flow.public_id, "nonce" => flow_nonce },
    )

    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    assert_equal "/sign/in?ri=jp", URI.parse(response.location).request_uri
    assert_nil request.session[:app_sign_in_flow_locator]

    get(response.location, headers: NAVIGATION_HEADERS)

    assert_response :success
    assert_not_equal I18n.t("errors.messages.phase_violation_refused"), response.body
    assert_equal ClientSignInFlow.state_id_for("MFA_PENDING"), stale_flow.reload.state_id
  ensure
    ClientSignInFlow.where(id: stale_flow.id).delete_all if stale_flow
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  private

  def issue_sign_in_handoff
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "authentication",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
      },
    ).transaction
    BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
  end

  # The integration session cannot be written directly, so the values are sealed into the
  # browser's session cookie the same way the application's cookie store would.
  def install_session_values(host, values)
    session_key = Rails.application.config.session_options.fetch(:key)
    sealed_state = { "session_id" => SecureRandom.hex(16) }.merge(request.session.to_hash).merge(values)
    request.cookie_jar.signed_or_encrypted[session_key] = { value: sealed_state }
    sealed_session = request.cookie_jar[session_key]
    cookies.delete(session_key)
    installed = cookies.merge("#{session_key}=#{Rack::Utils.escape(sealed_session)}", URI.parse("https://#{host}/")).any?

    assert installed, "The session cookie must be installed on the Auth host"
  end
end
