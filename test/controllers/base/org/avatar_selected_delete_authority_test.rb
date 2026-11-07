# frozen_string_literal: true

require "test_helper"

class Base::Org::AvatarSelectedDeleteAuthorityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @allow_forgery_protection = Rails.configuration.action_controller.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @allow_forgery_protection
  end

  test "selected Avatar deletion is refused without changing the Avatar or RP selection" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    https!

    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    root_token = OperatorToken.create!(authentication_epoch: 0, staff: operator)
    device_session = root_token.device_session_record!
    root_token.rotate_refresh_token! unless device_session.current_refresh_token_id == root_token.id

    client = OidcClientRegistry.find!("base-org-ww")
    redirect_uri = client.redirect_uris.first
    verifier = SecureRandom.urlsafe_base64(48)
    authorization_params = {
      client_id: client.client_id,
      redirect_uri:,
      response_type: "code",
      scope: "openid",
      state: SecureRandom.hex(16),
      nonce: SecureRandom.hex(16),
      code_challenge_method: "S256",
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
    }
    issued_code = OidcAuthorizationCodeIssuer.call(
      client:,
      params: authorization_params,
      resource: operator,
      session_token: root_token,
      authentication_event_at: 1.minute.ago,
    )
    token_url = OidcIssuer.token_endpoint("operator")
    exchange =
      OidcClientRegistry.stub(
        :verify_client_assertion,
        lambda { |authenticated_client_id, *, **|
          OidcClientRegistry::AssertionAuthenticationResult.new(
            authenticated: true,
            client: OidcClientRegistry.find(authenticated_client_id),
            step_up_claims_state: :none,
            step_up_expectation: nil,
          )
        },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: issued_code.code,
          redirect_uri: issued_code.redirect_uri,
          client_id: client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: token_url,
          code_verifier: verifier,
          expected_resource_type: "operator",
        )
      end

    assert_predicate exchange, :success?, exchange.inspect
    token_response = exchange.token_response
    id_token_payload, = JWT.decode(token_response.fetch(:id_token), nil, false)
    cell = RpCellBinding.for_client(client.client_id)
    enrollment = RpCallbackCommitter.call(
      cell:,
      issuer: id_token_payload.fetch("iss"),
      subject: id_token_payload.fetch("sub"),
      sid: id_token_payload.fetch("sid"),
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    rp_session = enrollment.session
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token_response.fetch(:access_token)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = token_response.fetch(:refresh_token)
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = rp_session.public_id
    headers = {
      "Authorization" => "Bearer #{token_response.fetch(:access_token)}",
      "Client-Agent" => "Mozilla/5.0 (compatible; Minitest)",
    }

    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    provisioning = AvatarProvisioning::Create.call(
      actor: operator,
      subject_type: :agent,
      subject: bootstrap.account,
      avatar_params: { moniker: "Bureau Avatar" },
      handle_params: { handle: "bureau-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: bootstrap.collective.public_id,
    )

    assert_predicate provisioning, :success?, provisioning.errors.inspect
    avatar = provisioning.avatar
    avatar_attributes_before = avatar.attributes
    RpBaseOrgSessionSelection.create!(
      rp_session_id: rp_session.id,
      account_public_id: bootstrap.account.public_id,
      organization_public_id: bootstrap.collective.public_id,
      organization_unit_public_id: bootstrap.unit.public_id,
      selected_at: RpBaseOrgSessionSelection.database_now,
    )
    RpBaseOrgSessionAvatarSelection.create!(
      rp_session_id: rp_session.id,
      avatar_public_id: avatar.public_id,
      selected_at: RpBaseOrgSessionAvatarSelection.database_now,
    )

    get base_org_avatar_url(ri: "jp", host: host), headers: headers.merge("Accept" => "text/html")

    assert_response :success
    csrf_token = response.body[/<meta name="csrf-token" content="([^"]+)"/, 1]

    assert_predicate csrf_token, :present?

    delete base_org_avatar_url(ri: "jp", host: host), headers: headers.merge(
      "Origin" => "https://#{host}",
      "X-CSRF-Token" => csrf_token,
    )

    assert_equal avatar_attributes_before, avatar.reload.attributes
    assert_equal avatar.public_id,
                 RpBaseOrgSessionAvatarSelection.find_by!(rp_session_id: rp_session.id).avatar_public_id
    assert_response :forbidden
  end
end
