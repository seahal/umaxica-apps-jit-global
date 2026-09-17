# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthCeremonyAdmissionBoundaryTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      name: "app",
      host_env: "PUBLIC_AUTH_SERVICE_URL",
      client_id: "core-next-rp",
      realm: "client",
      sign_in: :auth_app_sign_in_url,
    },
    {
      name: "com",
      host_env: "PUBLIC_AUTH_CORPORATE_URL",
      client_id: "core-com",
      realm: "visitor",
      sign_in: :auth_com_sign_in_url,
    },
    {
      name: "org",
      host_env: "PUBLIC_AUTH_STAFF_URL",
      client_id: "core-org",
      realm: "operator",
      sign_in: :auth_org_sign_in_url,
    },
  ].freeze

  test "absent admission stores no challenge and does not create a Base session token" do
    SURFACES.each do |surface|
      host = ENV.fetch(surface.fetch(:host_env))
      token_count = ClientToken.count
      open_session do |browser|
        browser.host!(host)
        browser.get(public_send(surface.fetch(:sign_in), ri: "jp"), headers: { "Host" => host })

        assert_equal 303, browser.response.status, surface.fetch(:name)
        assert_equal "/", URI.parse(browser.response.location).path, surface.fetch(:name)
        assert_nil browser.session[:oidc_authorization_login_challenge]
        assert_equal token_count, ClientToken.count
      end
    end
  end

  test "valid app admission stores the transaction challenge" do
    assert_valid_admission_challenge!(SURFACES.fetch(0))
  end

  test "valid com admission stores the transaction challenge" do
    assert_valid_admission_challenge!(SURFACES.fetch(1))
  end

  test "valid org admission stores the transaction challenge" do
    assert_valid_admission_challenge!(SURFACES.fetch(2))
  end

  test "replayed admission is rejected and does not create a Base session token" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    issuance = issue_transaction!(SURFACES.first)
    code = handoff_code(issuance)
    token_count = ClientToken.count

    open_session do |first|
      first.host!(host)
      first.get(auth_app_sign_in_url(ri: "jp", admission: code), headers: { "Host" => host })

      assert_equal 303, first.response.status
    end

    open_session do |second|
      second.host!(host)
      second.get(auth_app_sign_in_url(ri: "jp", admission: code), headers: { "Host" => host })

      assert_equal 400, second.response.status
      assert_nil second.session[:oidc_authorization_login_challenge]
      assert_equal token_count, ClientToken.count
    end
  end

  test "wrong-purpose admission is rejected" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! host
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_up",
      params: authorize_params("app").merge(screen_hint: "signup"),
    )

    get auth_app_sign_in_url(ri: "jp", admission: handoff_code(issuance)), headers: { "Host" => host }

    assert_response :bad_request
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "wrong-surface admission is rejected" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! host
    issuance = issue_transaction!(SURFACES.fetch(1))

    get auth_app_sign_in_url(ri: "jp", admission: handoff_code(issuance)), headers: { "Host" => host }

    assert_response :bad_request
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "email OTP leaf without admission does not create a ClientToken" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! host
    token_count = ClientToken.count

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { client_email: { pass_code: "000000" } },
          headers: { "Host" => host }

    assert_not_equal 200, response.status
    assert_equal token_count, ClientToken.count
  end

  private

  def assert_valid_admission_challenge!(surface)
    host = ENV.fetch(surface.fetch(:host_env))
    host!(host)
    issuance = issue_transaction!(surface)

    get(
      public_send(surface.fetch(:sign_in), ri: "jp", admission: handoff_code(issuance)),
      headers: { "Host" => host },
    )

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_equal issuance.transaction.login_challenge, session[:oidc_authorization_login_challenge]
  end

  def issue_transaction!(surface)
    OidcAuthorizationTransactionCoordinator.issue!(
      surface: surface.fetch(:name),
      intent: "sign_in",
      params: authorize_params(surface.fetch(:name)),
    )
  end

  def handoff_code(issuance)
    BaseAuthAdmissionCoordinator.issue_handoff!(transaction: issuance.transaction).code
  end

  def authorize_params(surface_name)
    spec = SURFACES.find { |row| row.fetch(:name) == surface_name }
    client = OidcClientRegistry.find!(spec.fetch(:client_id))
    redirect = client.redirect_uris_by_realm.fetch(spec.fetch(:realm)).first
    {
      response_type: "code",
      client_id: spec.fetch(:client_id),
      redirect_uri: redirect,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state-#{surface_name}",
      nonce: "nonce-#{surface_name}",
      scope: "openid profile",
    }
  end
end
