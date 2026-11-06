# typed: false
# frozen_string_literal: true

require "test_helper"

# Refresh is the long-lived credential path, so every binding a session carries is re-checked
# there: the idle window, a DPoP key thumbprint, a DBSC-bound device session, and the DBSC
# lifecycle state recorded on the token. A denied refresh answers 401 invalid_refresh_token,
# clears the auth cookies, and records the denial reason as a refresh occurrence.
class Base::EdgeV0TokenRefreshBindingTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators
  self.fixture_table_names = %w(clients operators)

  setup do
    # WU-02 V4: the token lifecycle endpoints live on the Visa (OP) host.
    @host = visa_host_for_test_surface(:app)
    host! @host
  end

  test "a session idle beyond the client window can no longer refresh" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(last_used_at: SecurityTokenLifetimes::CLIENT_IDLE_TTL.ago - 1.minute)

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
    assert_predicate response.cookies[AuthenticationBase::REFRESH_COOKIE_KEY].to_s, :empty?
  end

  test "a session used within the client window refreshes" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(last_used_at: SecurityTokenLifetimes::CLIENT_IDLE_TTL.ago + 5.minutes)

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :success
  end

  test "an operator session is held to the tighter operator idle window" do
    org_host = visa_host_for_test_surface(:org)
    host! org_host
    token = OperatorToken.create!(authentication_epoch: 0, staff: operators(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(last_used_at: SecurityTokenLifetimes::OPERATOR_IDLE_TTL.ago - 1.minute)

    assert_operator SecurityTokenLifetimes::OPERATOR_IDLE_TTL, :<, SecurityTokenLifetimes::CLIENT_IDLE_TTL

    post "/edge/v0/token/refresh",
         headers: {
           "Host" => org_host,
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
  end

  test "a DPoP-bound refresh without a proof is denied and recorded" do
    key = OpenSSL::PKey::EC.generate("prime256v1")
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(dpop_jkt: JitSecurityJwtThumbprintCalculator.calculate(JWT::JWK.new(key).export))

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
    occurrence = ClientOccurrence.where(event_type: "refresh_dpop_denied").order(:created_at).last

    assert_equal token.public_id, occurrence.context.fetch("token_id")
    assert_equal "missing", occurrence.context.fetch("reason")
    assert_equal "dpop", occurrence.context.fetch("device_source")
  end

  test "a DPoP-bound refresh with a proof from another key is denied as a thumbprint mismatch" do
    bound_key = OpenSSL::PKey::EC.generate("prime256v1")
    other_key = OpenSSL::PKey::EC.generate("prime256v1")
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(dpop_jkt: JitSecurityJwtThumbprintCalculator.calculate(JWT::JWK.new(bound_key).export))
    proof = JWT.encode(
      { "htm" => "POST",
        "htu" => "http://#{@host}/edge/v0/token/refresh",
        "iat" => Time.current.to_i,
        "jti" => SecureRandom.uuid, },
      other_key, "ES256", { "typ" => "dpop+jwt", "jwk" => JWT::JWK.new(other_key).export },
    )

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "DPoP" => proof,
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    occurrence = ClientOccurrence.where(event_type: "refresh_dpop_denied").order(:created_at).last

    assert_equal token.public_id, occurrence.context.fetch("token_id")
    assert_equal "jkt_mismatch", occurrence.context.fetch("reason")
  end

  test "a DPoP-bound refresh with a proof from the bound key refreshes" do
    key = OpenSSL::PKey::EC.generate("prime256v1")
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(dpop_jkt: JitSecurityJwtThumbprintCalculator.calculate(JWT::JWK.new(key).export))
    proof = JWT.encode(
      { "htm" => "POST",
        "htu" => "http://#{@host}/edge/v0/token/refresh",
        "iat" => Time.current.to_i,
        "jti" => SecureRandom.uuid, },
      key, "ES256", { "typ" => "dpop+jwt", "jwk" => JWT::JWK.new(key).export },
    )

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "DPoP" => proof,
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :success
  end

  test "a refresh on a DBSC-bound device session without a DBSC proof revokes the device session" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    sibling = ClientToken.create!(authentication_epoch: 0, user: clients(:one), device_session: token.device_session)
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    token.device_session.bind_dbsc!(session_id: "dbsc-session-id", public_key_thumbprint: "thumbprint")

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
    assert_predicate token.device_session.reload, :revoked?
    assert_predicate token.reload, :revoked?
    assert_predicate sibling.reload, :revoked?
    assert_predicate rp_session.reload, :revoked?
    occurrence = ClientOccurrence.where(event_type: "refresh_binding_denied").order(:created_at).last

    assert_equal "missing_proof", occurrence.context.fetch("reason")
  end

  test "a step-up install does not bypass DBSC on the next device-session refresh" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    refresh_plain = token.rotate_refresh_token!
    device_session = token.device_session
    session_id = SecureRandom.alphanumeric(21)
    key = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(key).export
    token.update!(
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::ACTIVE,
      dbsc_session_id: session_id,
      dbsc_public_key: jwk,
      dbsc_challenge: SecureRandom.hex(16),
      dbsc_challenge_issued_at: Time.current,
    )
    device_session.bind_dbsc!(
      session_id:,
      public_key_thumbprint: JitSecurityJwtThumbprintCalculator.calculate(jwk),
    )
    dbsc_binding_before = device_session.reload.attributes.slice(
      "dbsc_session_id_digest", "dbsc_public_key_thumbprint", "dbsc_bound_at",
    )

    install_step_up_for(actor)

    assert_equal dbsc_binding_before,
                 device_session.reload.attributes.slice(
                   "dbsc_session_id_digest", "dbsc_public_key_thumbprint", "dbsc_bound_at",
                 )
    assert_predicate device_session, :dbsc_bound?
    assert_equal session_id, token.reload.dbsc_session_id

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => [
             "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
             "#{AuthenticationBase::DBSC_COOKIE_KEY}=#{Rack::Utils.escape(session_id)}",
           ].join("; "),
         },
         as: :json

    assert_response :unauthorized
    assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
    assert_predicate device_session.reload, :revoked?
    occurrence = ClientOccurrence.where(event_type: "refresh_dbsc_denied").order(:created_at).last

    assert_equal "missing_proof", occurrence.context.fetch("reason")
  end

  test "a DBSC proof for another device session is denied as a session id mismatch" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.device_session.bind_dbsc!(session_id: "dbsc-session-id", public_key_thumbprint: "thumbprint")

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           AuthIoKeys::Headers::DBSC_SESSION_ID => %q("another-session-id"),
           AuthIoKeys::Headers::DBSC_RESPONSE => %q("proof"),
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    assert_predicate token.device_session.reload, :revoked?
    occurrence = ClientOccurrence.where(event_type: "refresh_binding_denied").order(:created_at).last

    assert_equal "session_id_mismatch", occurrence.context.fetch("reason")
  end

  test "an unverifiable DBSC proof for the bound device session is denied and revokes it" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.device_session.bind_dbsc!(session_id: "dbsc-session-id", public_key_thumbprint: "thumbprint")

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           AuthIoKeys::Headers::DBSC_SESSION_ID => %q("dbsc-session-id"),
           AuthIoKeys::Headers::DBSC_RESPONSE => %q("not-a-valid-proof"),
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    assert_predicate token.device_session.reload, :revoked?
    assert_predicate token.reload, :revoked?
    occurrence = ClientOccurrence.where(event_type: "refresh_binding_denied").order(:created_at).last

    assert_not_includes %w(missing_proof session_id_mismatch), occurrence.context.fetch("reason")
  end

  test "a refresh on a revoked device session is denied" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.device_session.revoke!(reason: "manual_review")

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
  end

  test "a DBSC-bound token without its bound cookie is denied" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::ACTIVE,
      dbsc_session_id: "bound-session",
    )

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    occurrence = ClientOccurrence.where(event_type: "refresh_dbsc_denied").order(:created_at).last

    assert_equal token.public_id, occurrence.context.fetch("token_id")
    assert_equal "missing_bound_cookie", occurrence.context.fetch("reason")
  end

  test "a DBSC-bound token whose lifecycle is not active is denied" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::FAILED,
    )

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
  end

  test "a legacy token that claims a failed DBSC lifecycle fails closed" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::FAILED,
    )

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    occurrence = ClientOccurrence.where(event_type: "refresh_binding_denied").order(:created_at).last

    assert_equal token.public_id, occurrence.context.fetch("token_id")
  end

  test "a legacy token whose DBSC registration offer expired refreshes and is downgraded to no binding" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::PENDING,
      dbsc_challenge_issued_at: AuthenticationBase::DBSC_COOKIE_TTL.ago - 1.minute,
    )

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :success
    assert_equal ClientTokenDbscStatus::NOTHING, token.reload.user_token_dbsc_status_id
  end

  test "a legacy token still inside its DBSC registration window refreshes and stays pending" do
    token = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.update_columns(
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::PENDING,
      dbsc_challenge_issued_at: 1.minute.ago,
    )

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :success
    assert_equal ClientTokenDbscStatus::PENDING, token.reload.user_token_dbsc_status_id
  end

  private

  def install_step_up_for(actor)
    cell = RpCellBinding.fetch("rp_base_app")
    session, state = create_step_up_state(actor:, cell:)
    transition = dispatch_step_up(cell:, state:)

    assert_equal :dispatching, transition.outcome

    access_payload, id_payload = step_up_payloads(actor:, cell:, session:)
    result = RpStepUpInstaller.call(
      cell:,
      state_ref: state.public_id,
      actor:,
      access_payload:,
      id_payload:,
      token_response: { access_token: "step-up-access", refresh_token: "step-up-refresh" },
    )

    assert_equal :installed, result.outcome
  end

  def create_step_up_state(actor:, cell:)
    issuer = OidcIssuer.for_resource_type("client")
    subject = OidcSubject.for(actor, resource_type: "client")
    sid = SecureRandom.alphanumeric(21)
    session = RpCallbackCommitter.call(
      cell:, issuer:, subject:, sid:, absolute_expires_at: 1.hour.from_now,
    ).session
    binding = RpBaseAppOpSessionBinding.includes(identity_binding: :principal).find(session.op_session_binding_id)
    base_payload = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "sid" => sid,
      "sub" => subject,
      "client_id" => cell.client_id,
      AuthenticationContextValue::CLAIM => AuthenticationContextValue::NORMAL_KEY,
    }
    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: binding.identity_binding.principal,
      rp_session: session,
      payload: base_payload,
      security_context: nil,
    )
    browser_binding = SecureRandom.urlsafe_base64(32)
    started = RpStepUpStartIssuer.call(
      cell:, access_state:, actor:, browser_binding:, return_target: "/settings/security",
    )
    [session, RpStepUpState.find_by!(public_id: started.state_ref)]
  end

  def dispatch_step_up(cell:, state:)
    RpStepUpStateTransitionWriter.call(cell:, state_ref: state.public_id) do
      RpStepUpStateTransitionWriter::Decision.new(
        to_status_id: RpStepUpStateStatus::DISPATCHING,
        reason_code: "dispatch_started",
        event_type: nil,
        payload: nil,
        outcome: :dispatching,
      )
    end
  end

  def step_up_payloads(actor:, cell:, session:)
    binding = RpBaseAppOpSessionBinding.find(session.op_session_binding_id)
    now = RpBaseAppRecord.database_now.to_i
    access_payload = {
      "iss" => binding.issuer,
      "aud" => [cell.client_id],
      "sid" => binding.sid,
      "sub" => OidcSubject.for(actor, resource_type: "client"),
      "client_id" => cell.client_id,
      AuthenticationContextValue::CLAIM => AuthenticationContextValue::NORMAL_KEY,
      "acr" => RpStepUpStartIssuer::STEP_UP_ACR,
      "amr" => ["passkey"],
      "auth_time" => now,
      "exp" => now + 300,
      "jti" => SecureRandom.hex(16),
    }
    [access_payload, access_payload.slice("iss", "aud", "sid", "sub")]
  end
end
