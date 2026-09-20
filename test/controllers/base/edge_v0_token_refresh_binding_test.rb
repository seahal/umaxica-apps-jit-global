# typed: false
# frozen_string_literal: true

require "test_helper"

# Refresh is the long-lived credential path, so every binding a session carries is re-checked
# there: the idle window, a DPoP key thumbprint, a DBSC-bound device session, and the DBSC
# lifecycle state recorded on the token. A denied refresh answers 401 invalid_refresh_token,
# clears the auth cookies, and records the denial reason as a refresh occurrence.
class Base::EdgeV0TokenRefreshBindingTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! @host
  end

  test "a session idle beyond the client window can no longer refresh" do
    token = ClientToken.create!(user: clients(:one))
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
    token = ClientToken.create!(user: clients(:one))
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
    org_host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! org_host
    token = OperatorToken.create!(staff: operators(:one))
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
    token = ClientToken.create!(user: clients(:one))
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
    token = ClientToken.create!(user: clients(:one))
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
    token = ClientToken.create!(user: clients(:one))
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
    token = ClientToken.create!(user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    sibling = ClientToken.create!(user: clients(:one), device_session: token.device_session)
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
    occurrence = ClientOccurrence.where(event_type: "refresh_binding_denied").order(:created_at).last

    assert_equal "missing_proof", occurrence.context.fetch("reason")
  end

  test "a DBSC proof for another device session is denied as a session id mismatch" do
    token = ClientToken.create!(user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.device_session.bind_dbsc!(session_id: "dbsc-session-id", public_key_thumbprint: "thumbprint")

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           AuthIoKeys::Headers::DBSC_SESSION_ID => "another-session-id",
           AuthIoKeys::Headers::DBSC_RESPONSE => "proof",
           "Cookie" => "#{AuthenticationBase::REFRESH_COOKIE_KEY}=#{Rack::Utils.escape(refresh_plain)}",
         },
         as: :json

    assert_response :unauthorized
    assert_predicate token.device_session.reload, :revoked?
    occurrence = ClientOccurrence.where(event_type: "refresh_binding_denied").order(:created_at).last

    assert_equal "session_id_mismatch", occurrence.context.fetch("reason")
  end

  test "an unverifiable DBSC proof for the bound device session is denied and revokes it" do
    token = ClientToken.create!(user: clients(:one))
    refresh_plain = token.rotate_refresh_token!
    token.device_session.bind_dbsc!(session_id: "dbsc-session-id", public_key_thumbprint: "thumbprint")

    post "/edge/v0/token/refresh",
         headers: {
           "Accept" => "application/json",
           AuthIoKeys::Headers::DBSC_SESSION_ID => "dbsc-session-id",
           AuthIoKeys::Headers::DBSC_RESPONSE => "not-a-valid-proof",
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
    token = ClientToken.create!(user: clients(:one))
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
    token = ClientToken.create!(user: clients(:one))
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
    token = ClientToken.create!(user: clients(:one))
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
    token = ClientToken.create!(user: clients(:one))
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
    token = ClientToken.create!(user: clients(:one))
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
    token = ClientToken.create!(user: clients(:one))
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
end
