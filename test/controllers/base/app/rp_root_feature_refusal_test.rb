# frozen_string_literal: true

require "test_helper"

class Base::App::RpRootFeatureRefusalTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "a valid Base RP session receives a localized refusal for unavailable root-dependent features" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!
    cell = RpCellBinding.for_client("base-app-ww")
    issuer = OidcIssuer.for_resource_type("client")
    subject = OidcSubject.for(actor, resource_type: "client")
    sid = SecureRandom.uuid
    enrollment = RpCallbackCommitter.call(
      cell: cell, issuer: issuer, subject: subject, sid: sid, absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?

    key = OpenSSL::PKey::EC.generate("secp384r1")
    now = Time.current.to_i
    access_token = JWT.encode(
      { "iss" => issuer,
        "aud" => [cell.client_id],
        "sub" => subject,
        "sid" => sid,
        "iat" => now,
        "nbf" => now - 1,
        "exp" => now + 300,
        "jti" => SecureRandom.uuid,
        "scope" => "openid",
        "client_id" => cell.client_id,
        "authn_ctx" => "normal", },
      key, "ES384", { "kid" => "rp-refusal-test", "typ" => "at+jwt" },
    )
    jwks = OidcOpJwksClient.new(
      jwks_uri: OidcIssuer.jwks_uri("client"),
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "rp-refusal-test")] } },
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    owner = Minitest::Mock.new
    log_messages = []
    capture_log = ->(message = nil, *_arguments, **_keywords, &_block) { log_messages << message if message }
    signed_target = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    ).generate(
      { "flow" => "step_up.bootstrap",
        "surface" => "app",
        "session_nonce" => "origin-session",
        "pt" => "/secret_issuances/#{"a" * 21}", },
      purpose: :path_target, expires_in: 5.minutes,
    )
    registration_side_effects_before = [
      ClientAuthAdmissionBinding.count,
      IdentityPasskeyCeremonyCandidate.count,
      ClientTotpCredential.count,
    ]
    requests = [
      -> { get("/secrets?ri=jp") },
      -> { post("/secrets?ri=jp") },
      -> { get("/secret_issuances/#{"a" * 21}?ri=jp") },
      -> { post("/secret_issuances/#{"a" * 21}/presentation?ri=jp") },
      -> { get("/sessions?ri=jp") },
      -> { delete("/sessions/other?ri=jp") },
      -> { get("/verification?ri=jp", params: { scope: "settings_secret_credential" }) },
      -> { get("/verification/setup?ri=jp", params: { scope: "settings_secret_credential" }) },
      -> { get("/verification?ri=jp", params: { scope: "settings_passkey", pt: signed_target }) },
      -> { post("/identity/passkeys?ri=jp") },
      -> { post("/identity/totps?ri=jp") },
      -> {
        get(
          "/verification?ri=jp",
          params: { scope: "settings_passkey", return_target: "/secret_issuances/#{"a" * 21}" },
        )
      },
    ]

    RuntimeRole.stub(:current, "rp-base-app-ww") do
      RuntimeRole.stub(:rp_browser_admission_open?, true) do
        OidcOpJwksClient.stub(:for_resource_type, jwks) do
          OrgAdminAuthorityClient.stub(:new, ->(**) { owner }) do
            Rails.logger.stub(:info, capture_log) do
              requests.each do |request_call|
                request_call.call

                assert_response :service_unavailable
                assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
                assert_includes response.headers.fetch("Cache-Control"), "no-store"
              end
              get "/verification?ri=jp"

              assert_response :success
              get "/verification?ri=jp", params: { scope: "settings_passkey", return_target: ["/identity"] }

              assert_response :bad_request
              cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
              get "/sessions?ri=jp"

              assert_not_equal 503, response.status
            end
          end
        end
      end
    end

    events =
      log_messages.filter_map do |message|
        JSON.parse(message) if message.is_a?(String) && message.start_with?("{")
      end.select { |event| event["event"] == "auth.rp_feature.refused" }

    assert_equal requests.size, events.size
    assert events.all? { |event| event.dig("data", "reason_code") == "rp_root_session_unavailable" }
    assert_not_includes JSON.generate(events), access_token
    assert_equal registration_side_effects_before, [
      ClientAuthAdmissionBinding.count,
      IdentityPasskeyCeremonyCandidate.count,
      ClientTotpCredential.count,
    ]
    assert_mock owner
  end
end
