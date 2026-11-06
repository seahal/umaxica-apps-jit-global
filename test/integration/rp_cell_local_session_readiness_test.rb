# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

# R5-WU17 per-cell readiness (AT-R5-17, source side): as its own `rp-*` process each of the nine
# JP-development cells authenticates a protected request from its local session and the OP-verified
# Access JWT only, refuses the same Access JWT without that session, and refuses it once the local
# OP binding is revoked (a back-channel logout tombstone).
class RpCellLocalSessionReadinessTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  # client_id => [host env, protected GET path]
  CELLS = {
    "base-app-ww" => ["PUBLIC_BASE_SERVICE_URL", "/accounts"],
    "base-org-ww" => ["PUBLIC_BASE_STAFF_URL", "/accounts"],
    "core-app-jp" => ["PUBLIC_CORE_SERVICE_URL", "/api/v0/session"],
    "core-org-jp" => ["PUBLIC_CORE_STAFF_URL", "/api/v0/session"],
    "warp-app-jp" => ["PUBLIC_WARP_SERVICE_URL", "/dashboard"],
    "warp-org-jp" => ["PUBLIC_WARP_STAFF_URL", "/dashboard"],
    "palm-app-jp" => ["PUBLIC_PALM_SERVICE_URL", "/dashboard"],
    "edit-org-ww" => ["PUBLIC_EDIT_STAFF_URL", "/dashboard"],
    "tech-org-ww" => ["PUBLIC_TECH_STAFF_URL", "/dashboard"],
  }.freeze

  CELLS.each do |client_id, (host_env, path)|
    test "#{client_id} authenticates from its local session and refuses without it or after logout" do
      host!(ENV.fetch(host_env))
      https!
      actor, root_token = cell_actor(client_id)

      with_core_browser_api_enabled do
        as_rp_cell(client_id) do
          token_response, _payload, local_session = sign_in_rp_cell(client_id, actor:, root_token:)
          get path, params: { ri: "jp" }

          assert authenticated_response?(path),
                 "#{client_id} #{path}: #{response.status} #{response.location} #{response.body.to_s.first(200)}"

          # The same Access JWT without the local session is not authenticated.
          session_cookie = cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
          cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
          get path, params: { ri: "jp" }

          assert_not authenticated_response?(path)

          # A revoked local OP binding (logout tombstone) stops authenticating the same credentials.
          cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = session_cookie
          cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token_response.fetch(:access_token)
          binding_class = "#{RpCellBinding.for_client(client_id).record_prefix}OpSessionBinding".constantize
          binding_class.where(id: local_session.op_session_binding_id).update_all(revoked_at: Time.current)
          get path, params: { ri: "jp" }

          assert_not authenticated_response?(path)
        end
      end
    end
  end

  test "Core APP RP-cell sign-out commits local revocation before revoking its refresh token" do
    client_id = "core-app-jp"
    client = OidcClientRegistry.find!(client_id)
    cell = RpCellBinding.for_client(client_id)
    previous_runtime_role = ENV["UMAXICA_RUNTIME_ROLE"]
    previous_browser_admission = ENV["UMAXICA_RP_BROWSER_ADMISSION"]
    previous_jwks_clients = OidcOpJwksClient::CLIENTS.dup
    ENV["UMAXICA_RUNTIME_ROLE"] = "#{cell.connection.tr("_", "-")}-#{cell.region}"
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "open"
    OidcOpJwksClient::CLIENTS.clear
    host!(ENV.fetch("PUBLIC_CORE_SERVICE_URL"))
    https!

    actor = clients(:one)
    root_token = ClientToken.create!(
      authentication_epoch: 0,
      user: actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    verifier = SecureRandom.urlsafe_base64(48)
    authorize_params = {
      client_id: client_id,
      redirect_uri: client.redirect_uris.first,
      response_type: "code",
      scope: "openid",
      state: SecureRandom.hex(16),
      nonce: SecureRandom.hex(16),
      code_challenge_method: "S256",
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
    }
    authorization_code = OidcAuthorizationCodeIssuer.call(
      client:,
      params: authorize_params,
      resource: actor,
      session_token: root_token,
      authentication_event_at: 1.minute.ago,
    )
    token_result =
      OidcClientRegistry.stub(
        :verify_client_assertion,
        ->(asserted_client_id, *, **) {
          OidcClientRegistry::AssertionAuthenticationResult.new(
            authenticated: true, client: OidcClientRegistry.find(asserted_client_id),
            step_up_claims_state: :none, step_up_expectation: nil,
          )
        },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: authorization_code.code,
          redirect_uri: authorization_code.redirect_uri,
          client_id: client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "local-rp-cell-test-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"),
          code_verifier: verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate token_result, :success?, "the local OP code exchange must succeed"

    token_response = token_result.token_response
    id_token_payload, = JWT.decode(token_response.fetch(:id_token), nil, false)
    grant = OpAppGrant.find_by!(
      public_id: id_token_payload.fetch("sid"),
      oidc_client_id: client.client_id,
    )
    enrollment = RpCallbackCommitter.call(
      cell:,
      issuer: id_token_payload.fetch("iss"),
      subject: id_token_payload.fetch("sub"),
      sid: id_token_payload.fetch("sid"),
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?, "the verified OP result must create its local RP session"

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token_response.fetch(:access_token)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = token_response.fetch(:refresh_token)
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id

    revocation_calls = []
    revocation_result = Object.new
    revocation_result.define_singleton_method(:success?) { false }
    revocation_result.define_singleton_method(:outcome) { :network_unavailable }
    OidcOpRevocationClient.stub(
      :revoke,
      ->(**arguments) {
        revocation_calls << arguments.merge(local_session_revoked: enrollment.session.reload.revoked_at.present?)
        revocation_result
      },
    ) do
      RpCoreAppRecord.stub(:connected_to, ->(*, **) { raise ActiveRecord::ConnectionNotEstablished }) do
        post(core_app_sign_out_url(ri: "jp"))
      end

      assert_response :service_unavailable
      assert_equal(
        [true, token_response.fetch(:access_token), token_response.fetch(:refresh_token), enrollment.session.public_id,
         [],],
        [enrollment.session.reload.active?, cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE],
         cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE],
         cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], revocation_calls,],
      )

      original_transaction = RpCoreAppRecord.method(:transaction)
      commit_failure =
        lambda do |*arguments, **keywords, &operation|
          original_transaction.call(*arguments, **keywords) do
            operation.call
            raise ActiveRecord::StatementInvalid, "injected local RP session commit failure"
          end
        end
      RpCoreAppRecord.stub(:transaction, commit_failure) do
        post(core_app_sign_out_url(ri: "jp"))
      end

      assert_response :service_unavailable
      assert_equal(
        [true, token_response.fetch(:access_token), token_response.fetch(:refresh_token), enrollment.session.public_id,
         [],],
        [enrollment.session.reload.active?, cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE],
         cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE],
         cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], revocation_calls,],
      )

      post(core_app_sign_out_url(ri: "jp"))
    end

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal OidcIssuer.host_for_client(client), location.host
    assert_equal "/oidc/logout", location.path
    assert_equal client.client_id, query.fetch("client_id")
    assert_equal token_response.fetch(:refresh_token), revocation_calls.fetch(0).fetch(:token)
    assert_equal "client", revocation_calls.fetch(0).fetch(:resource_type)
    assert_equal client.client_id, revocation_calls.fetch(0).fetch(:client_id)
    assert revocation_calls.fetch(0).fetch(:local_session_revoked)
    assert_not query.key?("id_token_hint")
    assert_predicate query.fetch("post_logout_redirect_uri"), :present?
    assert_predicate query.fetch("state"), :present?
    assert_predicate enrollment.session.reload.revoked_at, :present?
    assert_predicate grant.reload, :active?
    assert_predicate root_token.reload, :currently_usable?
    assert_empty cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s
    assert_empty cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s
    assert_empty cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE].to_s
  ensure
    if previous_jwks_clients
      OidcOpJwksClient::CLIENTS.clear
      previous_jwks_clients.each { |client_key, client_value| OidcOpJwksClient::CLIENTS[client_key] = client_value }
    end
    previous_runtime_role.nil? ? ENV.delete("UMAXICA_RUNTIME_ROLE") : ENV["UMAXICA_RUNTIME_ROLE"] =
                                                                        previous_runtime_role
    previous_browser_admission.nil? ? ENV.delete("UMAXICA_RP_BROWSER_ADMISSION") :
      ENV["UMAXICA_RP_BROWSER_ADMISSION"] = previous_browser_admission
  end

  test "Core ORG RP-cell sign-out commits local revocation before revoking its refresh token" do
    client_id = "core-org-jp"
    resource_type = "operator"
    client = OidcClientRegistry.find!(client_id)
    cell = RpCellBinding.for_client(client_id)
    previous_runtime_role = ENV["UMAXICA_RUNTIME_ROLE"]
    previous_browser_admission = ENV["UMAXICA_RP_BROWSER_ADMISSION"]
    previous_jwks_clients = OidcOpJwksClient::CLIENTS.dup
    ENV["UMAXICA_RUNTIME_ROLE"] = "rp-core-org-jp"
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "open"
    OidcOpJwksClient::CLIENTS.clear
    host!(ENV.fetch("PUBLIC_CORE_STAFF_URL"))
    https!

    actor = operators(:one)
    root_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: actor,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    verifier = SecureRandom.urlsafe_base64(48)
    authorize_params = {
      client_id: client_id,
      redirect_uri: client.redirect_uris.first,
      response_type: "code",
      scope: "openid",
      state: SecureRandom.hex(16),
      nonce: SecureRandom.hex(16),
      code_challenge_method: "S256",
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
    }
    authorization_code = OidcAuthorizationCodeIssuer.call(
      client:,
      params: authorize_params,
      resource: actor,
      session_token: root_token,
      authentication_event_at: 1.minute.ago,
    )
    token_result =
      OidcClientRegistry.stub(
        :verify_client_assertion,
        ->(asserted_client_id, *, **) {
          OidcClientRegistry::AssertionAuthenticationResult.new(
            authenticated: true, client: OidcClientRegistry.find(asserted_client_id),
            step_up_claims_state: :none, step_up_expectation: nil,
          )
        },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: authorization_code.code,
          redirect_uri: authorization_code.redirect_uri,
          client_id: client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "local-rp-cell-test-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint(resource_type),
          code_verifier: verifier,
          expected_resource_type: resource_type,
        )
      end

    assert_predicate token_result, :success?

    token_response = token_result.token_response
    id_token_payload, = JWT.decode(token_response.fetch(:id_token), nil, false)
    grant = OpOrgGrant.find_by!(
      public_id: id_token_payload.fetch("sid"),
      oidc_client_id: client.client_id,
    )
    enrollment = RpCallbackCommitter.call(
      cell:,
      issuer: id_token_payload.fetch("iss"),
      subject: id_token_payload.fetch("sub"),
      sid: id_token_payload.fetch("sid"),
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token_response.fetch(:access_token)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = token_response.fetch(:refresh_token)
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    revocation_calls = []
    revocation_result = Object.new
    revocation_result.define_singleton_method(:success?) { false }
    revocation_result.define_singleton_method(:outcome) { :network_unavailable }

    OidcOpRevocationClient.stub(
      :revoke,
      ->(**arguments) {
        revocation_calls << arguments.merge(local_session_revoked: enrollment.session.reload.revoked_at.present?)
        revocation_result
      },
    ) do
      original_transaction = RpCoreOrgRecord.method(:transaction)
      commit_failure =
        lambda do |*arguments, **keywords, &operation|
          original_transaction.call(*arguments, **keywords) do
            operation.call
            raise ActiveRecord::StatementInvalid, "injected local RP session commit failure"
          end
        end
      RpCoreOrgRecord.stub(:transaction, commit_failure) do
        post(core_org_sign_out_url(ri: "jp"))
      end

      assert_response :service_unavailable
      assert_equal(
        [true, token_response.fetch(:access_token), token_response.fetch(:refresh_token), enrollment.session.public_id,
         [],],
        [enrollment.session.reload.active?, cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE],
         cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE],
         cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], revocation_calls,],
      )

      post(core_org_sign_out_url(ri: "jp"))
    end

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal OidcIssuer.host_for_client(client), location.host
    assert_equal "/oidc/logout", location.path
    assert_equal client.client_id, query.fetch("client_id")
    assert_equal token_response.fetch(:refresh_token), revocation_calls.fetch(0).fetch(:token)
    assert_equal resource_type, revocation_calls.fetch(0).fetch(:resource_type)
    assert_equal client.client_id, revocation_calls.fetch(0).fetch(:client_id)
    assert revocation_calls.fetch(0).fetch(:local_session_revoked)
    assert_not query.key?("id_token_hint")
    assert_predicate query.fetch("post_logout_redirect_uri"), :present?
    assert_predicate query.fetch("state"), :present?
    assert_predicate enrollment.session.reload.revoked_at, :present?
    assert_predicate grant.reload, :active?
    assert_predicate root_token.reload, :currently_usable?
    assert_empty cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s
    assert_empty cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s
    assert_empty cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE].to_s
  ensure
    if previous_jwks_clients
      OidcOpJwksClient::CLIENTS.clear
      previous_jwks_clients.each { |client_key, client_value| OidcOpJwksClient::CLIENTS[client_key] = client_value }
    end
    previous_runtime_role.nil? ? ENV.delete("UMAXICA_RUNTIME_ROLE") : ENV["UMAXICA_RUNTIME_ROLE"] =
                                                                        previous_runtime_role
    previous_browser_admission.nil? ? ENV.delete("UMAXICA_RP_BROWSER_ADMISSION") :
      ENV["UMAXICA_RP_BROWSER_ADMISSION"] = previous_browser_admission
  end

  CELLS.each_key do |client_id|
    test "#{client_id} signs out locally before revoking its Refresh Token" do
      assert_rp_cell_sign_out(client_id)
    end
  end

  private

  # Core's session endpoint answers 200 either way and states the outcome in its body. Base app
  # requires a selected account first: a signed-in actor whose OP root has none is sent to the
  # selector (an authenticated-only step), an unauthenticated one to sign-in.
  def authenticated_response?(path)
    return response.status == 200 && response.parsed_body["authenticated"] == true if path == "/api/v0/session"
    return response.status == 200 unless response.redirect? && host == ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    URI.parse(response.location).path == "/selector"
  end

  def with_core_browser_api_enabled
    previous = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    yield
  ensure
    previous.nil? ? ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED") : ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = previous
  end

  def cell_actor(client_id)
    actor =
      case RpCellBinding.for_client(client_id).realm
      when "app" then clients(:one)
      else operators(:one)
      end
    grant_tech_access(actor) if client_id == "tech-org-ww"
    [actor, authentication_harness_create_token(actor)]
  end

  # Tech admits only an operator holding the in-force tech.access capability.
  def grant_tech_access(operator)
    OperatorCapabilityGrant.create!(
      operator:, granted_by_operator: operators(:two), origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
  end

  def assert_rp_cell_sign_out(client_id)
    previous_jwks_clients = OidcOpJwksClient::CLIENTS.dup
    client = OidcClientRegistry.find!(client_id)
    resource_type = OidcIssuer.resource_type_for_client(client)

    as_rp_cell(client_id) do
      host!(ENV.fetch(CELLS.fetch(client_id).first))
      https!
      credentials = rp_cell_logout_credentials(client_id)
      outcome = submit_rp_cell_logout(credentials)

      assert_rp_cell_logout_handoff(client_id, resource_type, credentials, outcome)
      assert_rp_cell_logout_state(client_id, credentials)
    end
  ensure
    OidcOpJwksClient::CLIENTS.clear
    previous_jwks_clients&.each { |client_key, client_value| OidcOpJwksClient::CLIENTS[client_key] = client_value }
  end

  def rp_cell_logout_credentials(client_id)
    actor, root_token = cell_actor(client_id)
    token_response, payload, local_session = sign_in_rp_cell(client_id, actor:, root_token:)
    resource_type = OidcIssuer.resource_type_for_client(OidcClientRegistry.find!(client_id))
    grant_class = resource_type.eql?("operator") ? OpOrgGrant : OpAppGrant
    grant = grant_class.find_by!(public_id: payload.fetch("sid"), oidc_client_id: client_id)

    { resource_type:, root_token:, token_response:, local_session:, grant: }
  end

  def submit_rp_cell_logout(credentials)
    revocation_calls = []
    revocation_result = Object.new
    revocation_result.define_singleton_method(:success?) { false }
    revocation_result.define_singleton_method(:outcome) { :network_unavailable }
    local_session = credentials.fetch(:local_session)

    OidcOpRevocationClient.stub(
      :revoke,
      ->(**arguments) {
        revocation_calls << arguments.merge(local_session_revoked: local_session.reload.revoked_at.present?)
        revocation_result
      },
    ) do
      post("/sign/out", params: { ri: "jp" })
    end

    { revocation_calls:, location: response.location }
  end

  def assert_rp_cell_logout_handoff(client_id, resource_type, credentials, outcome)
    assert_response :see_other, client_id
    location = URI.parse(outcome.fetch(:location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)
    revocation = outcome.fetch(:revocation_calls).fetch(0)
    token_response = credentials.fetch(:token_response)

    assert_equal "/oidc/logout", location.path, client_id
    assert_equal URI.parse(OidcIssuer.end_session_endpoint(resource_type)).host, location.host, client_id
    assert_equal client_id, query.fetch("client_id"), client_id
    assert_equal token_response.fetch(:refresh_token), revocation.fetch(:token), client_id
    assert_equal resource_type, revocation.fetch(:resource_type), client_id
    assert revocation.fetch(:local_session_revoked)
    assert_not query.key?("id_token_hint"), client_id

    assert_predicate query.fetch("post_logout_redirect_uri"), :present?, client_id
    assert_predicate query.fetch("state"), :present?, client_id
  end

  def assert_rp_cell_logout_state(client_id, credentials)
    assert_predicate credentials.fetch(:local_session).reload.revoked_at, :present?, client_id
    assert_predicate credentials.fetch(:grant).reload, :active?, client_id
    assert_predicate credentials.fetch(:root_token).reload, :currently_usable?, client_id
    assert_empty cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s, client_id
    assert_empty cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s, client_id
    assert_empty cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE].to_s, client_id
  end
end
