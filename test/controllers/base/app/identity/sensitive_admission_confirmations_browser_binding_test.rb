# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::SensitiveAdmissionConfirmationsBrowserBindingTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    https!
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    cell = RpCellBinding.for_client("base-app-ww")
    issuer = OidcIssuer.for_resource_type("client")
    subject = OidcSubject.for(@client, resource_type: "client")
    sid = SecureRandom.uuid
    enrollment = RpCallbackCommitter.call(
      cell: cell,
      issuer: issuer,
      subject: subject,
      sid: sid,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    @rp_session = enrollment.session
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    candidate = BaseSelectorAuthority.new(
      surface: :app,
      principal: @client,
      session: @rp_session,
    ).selectable_candidates.fetch(0).fetch(:public)
    selection = BaseSelectorAuthority.select(
      surface: :app,
      principal: @client,
      session: @rp_session,
      params: candidate,
    )

    assert_equal "selected", selection.fetch(:status)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    now = Time.current.to_i
    @access_token = JWT.encode(
      {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "sub" => subject,
        "sid" => sid,
        "iat" => now,
        "nbf" => now - 1,
        "exp" => now + 300,
        "jti" => SecureRandom.uuid,
        "scope" => "openid",
        "client_id" => cell.client_id,
        "authn_ctx" => "normal",
      },
      key,
      "ES384",
      { "kid" => "sensitive-admission-browser-binding-test", "typ" => "at+jwt" },
    )
    @jwks = OidcOpJwksClient.new(
      jwks_uri: OidcIssuer.jwks_uri("client"),
      fetcher: -> {
        { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "sensitive-admission-browser-binding-test")] }
      },
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = @rp_session.public_id
  end

  test "sensitive admission confirmation refuses a browser without its Base marker" do
    admission_ref = "a" * 21
    entry_ref = SecureRandom.uuid
    counts_before = [ClientVisaSensitiveAdmission.count, ClientAuthAdmissionBinding.count]

    RuntimeRole.stub(:current, "rp-base-app-ww") do
      RuntimeRole.stub(:rp_browser_admission_open?, true) do
        OidcOpJwksClient.stub(:for_resource_type, @jwks) do
          visa_client = VisaSensitiveAdmissionClient.new(surface: "app", access_token: @access_token)
          visa_client.stub(:confirm_browser!, ->(**) { flunk("Visa must not be called without browser proof") }) do
            VisaSensitiveAdmissionClient.stub(:new, visa_client) do
              get "/identity/sensitive_admissions/#{admission_ref}/confirmation", params: { entry_ref: entry_ref }

              assert_response :bad_request
              post "/identity/sensitive_admissions/#{admission_ref}/confirmation",
                   params: { entry_ref: entry_ref }

              assert_response :bad_request
            end
          end
        end
      end
    end

    assert_equal counts_before, [ClientVisaSensitiveAdmission.count, ClientAuthAdmissionBinding.count]
  end

  test "Base confirms an O-9 admission only with the original session's browser marker" do
    issuance = VisaSensitiveAdmissionClient::IssuanceResult.new(
      status: :ok,
      admission_ref: "c" * 21,
      authorization_url: "https://visa.umaxica.app/oauth/authorize?stub=1",
    )
    admission_issuer = VisaSensitiveAdmissionClient.new(surface: "app", access_token: @access_token)
    admission_issuer.stub(
      :issue_admission!, ->(attributes:) {
                           assert_equal "passkey_registration", attributes.fetch(:purpose)
                           issuance
                         },
    ) do
      RuntimeRole.stub(:current, "rp-base-app-ww") do
        RuntimeRole.stub(:rp_browser_admission_open?, true) do
          OidcOpJwksClient.stub(:for_resource_type, @jwks) do
            VisaSensitiveAdmissionClient.stub(:new, admission_issuer) do
              post "/identity/passkeys", params: { ri: "jp" }

              assert_response :see_other
            end
          end
        end
      end
    end

    admission_ref = "b" * 21
    entry_ref = SecureRandom.uuid
    browser_nonce = cookies["_umaxica_app_session"]

    assert_not_nil browser_nonce
    digest = AuthAdmissionBinding.browser_digest(surface: "app", entry_ref: @rp_session.public_id, nonce: browser_nonce)
    confirmation = VisaSensitiveAdmissionClient::Result.new(status: :ok)
    confirmed = nil
    confirmation_client = VisaSensitiveAdmissionClient.new(surface: "app", access_token: @access_token)
    confirmation_client.stub(
      :confirm_browser!, ->(**arguments) {
                           confirmed = arguments
                           confirmation
                         },
    ) do
      RuntimeRole.stub(:current, "rp-base-app-ww") do
        RuntimeRole.stub(:rp_browser_admission_open?, true) do
          OidcOpJwksClient.stub(:for_resource_type, @jwks) do
            VisaSensitiveAdmissionClient.stub(:new, confirmation_client) do
              get "/identity/sensitive_admissions/#{admission_ref}/confirmation", params: { entry_ref: entry_ref }

              assert_response :success
              assert_includes response.body, 'id="base-ceremony-binding-confirmation-form"'
              post "/identity/sensitive_admissions/#{admission_ref}/confirmation",
                   params: { entry_ref: entry_ref }

              assert_response :see_other
              assert_equal "/ceremony_bindings", URI.parse(response.location).path
            end
          end
        end
      end
    end

    assert_equal(
      { admission_ref: admission_ref, rp_session_ref: @rp_session.public_id, browser_binding_digest: digest },
      confirmed,
    )
  end
end
