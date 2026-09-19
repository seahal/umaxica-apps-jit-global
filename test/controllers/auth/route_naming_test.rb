# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::RouteNamingTest < ActionDispatch::IntegrationTest
  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  SURFACES = {
    app: BOOT_HOSTS.sign_service.host,
    com: BOOT_HOSTS.sign_corporate.host,
    org: BOOT_HOSTS.sign_staff.host,
  }.freeze

  test "sign entry helpers use explicit lifecycle resources" do
    assert_equal "/sign/up", auth_app_sign_up_path
    assert_equal "/sign/in", auth_app_sign_in_path
  end

  test "sign logout helpers expose the explicit ceremony lifecycle" do
    helpers = Rails.application.routes.url_helpers

    assert_respond_to helpers, :auth_app_sign_out_path
    assert_respond_to helpers, :new_auth_app_sign_out_path
    assert_respond_to helpers, :edit_auth_app_sign_out_path
    assert_not_respond_to helpers, :auth_app_sign_out_confirmation_path
    assert_not_respond_to helpers, :auth_app_sign_out_attempt_path
    assert_not_respond_to helpers, :complete_auth_app_sign_out_path
    assert_not_respond_to helpers, :auth_app_sign_out_completion_path
  end

  test "top-level sign entry routes resolve conventionally on every sign surface" do
    SURFACES.each_key do |surface|
      assert_recognizes_sign_route(surface, "/sign/up", :get, "auth/#{surface}/sign/ups", "show")
      assert_recognizes_sign_route(surface, "/sign/in", :get, "auth/#{surface}/sign/ins", "show")
      assert_unrecognized(surface, "/sign/up/entrance", :get)
      assert_unrecognized(surface, "/sign/in/entrance", :get)
      assert_recognizes_sign_route(surface, "/sign/out/new", :get, "auth/#{surface}/sign/outs", "new")
      assert_recognizes_sign_route(surface, "/sign/out/edit", :get, "auth/#{surface}/sign/outs", "edit")
      assert_unrecognized(surface, "/sign/out/complete", :get)
      assert_recognizes_sign_route(surface, "/sign/out", :post, "auth/#{surface}/sign/outs", "create")
      assert_recognizes_sign_route(surface, "/sign/out", :delete, "auth/#{surface}/sign/outs", "destroy")
      assert_unrecognized(surface, "/signed-out", :get)
      assert_unrecognized(surface, "/oidc/backchannel/logout", :post)
      assert_unrecognized(surface, "/oidc/authorization", :get)
      assert_unrecognized(surface, "/oidc/callback", :get)
      assert_unrecognized(surface, "/oidc/frontchannel_logout", :get)
      assert_unrecognized(surface, "/oidc/logout", :get)
      assert_unrecognized(surface, "/oidc/logout", :post)
      assert_unrecognized(surface, "/sign/out/confirmation", :get)
      assert_unrecognized(surface, "/sign/out/attempt", :post)
      assert_unrecognized(surface, "/sign/out/completion", :get)
    end
  end

  test "sign check routes use checks controller namespace and old checkpoint route is absent" do
    assert_recognizes_sign_route(:app, "/sign/in/check", :get, "auth/app/sign/in/checks", "show")
    assert_recognizes_sign_route(:com, "/sign/in/check", :get, "auth/com/sign/in/checks", "show")
    assert_recognizes_sign_route(:org, "/sign/in/check", :get, "auth/org/sign/in/checks", "show")

    SURFACES.each_key do |surface|
      assert_unrecognized(surface, "/sign/in/check", :patch)
      assert_unrecognized(surface, "/sign/in/check", :delete)
      assert_unrecognized(surface, "/sign/in/checkpoint", :get)
      assert_unrecognized(surface, "/sign/in/checkpoint", :patch)
      assert_unrecognized(surface, "/sign/in/checkpoint", :delete)
    end
  end

  test "com org social routes remain absent from sign authority surfaces" do
    assert_unrecognized(:com, "/social/apple/connection", :get)
    assert_unrecognized(:org, "/social/google/connection", :get)
  end

  test "preference routes are not exposed on sign" do
    assert_unrecognized(:app, "/preference/language/edit", :get)
  end

  test "auth app settings keeps only credential ceremony settings" do
    helper_names = Rails.application.routes.named_routes.helper_names.map(&:to_s)

    %w(
      auth_app_settings
      auth_app_settings_passkey
      auth_app_settings_passkeys_options
      auth_app_settings_passkeys_verification
      auth_app_settings_totp
      auth_app_settings_apple
      auth_app_settings_google
    ).each do |prefix|
      assert helper_names.any? { |name| name.start_with?(prefix) }, "#{prefix} must remain"
    end

    %w(
      auth_app_settings_email
      auth_app_settings_telephone
      auth_app_settings_birthdate
      auth_app_settings_secret
      auth_app_settings_session
      auth_app_settings_revocation
      auth_app_settings_activity
      auth_app_settings_withdrawal
      auth_app_settings_mfa
    ).each do |prefix|
      assert helper_names.none? { |name| name.start_with?(prefix) }, "#{prefix} must not exist"
    end
  end

  test "auth com settings keeps only passkey ceremony settings" do
    helper_names = Rails.application.routes.named_routes.helper_names.map(&:to_s)

    %w(
      auth_com_settings
      auth_com_settings_passkey
      auth_com_settings_passkeys_options
      auth_com_settings_passkeys_verification
    ).each do |prefix|
      assert helper_names.any? { |name| name.start_with?(prefix) }, "#{prefix} must remain"
    end

    %w(
      auth_com_settings_totp
      auth_com_settings_google
      auth_com_settings_apple
      auth_com_settings_entra
      auth_com_settings_email
      auth_com_settings_telephone
      auth_com_settings_birthdate
      auth_com_settings_secret
      auth_com_settings_session
      auth_com_settings_revocation
      auth_com_settings_activity
      auth_com_settings_withdrawal
      auth_com_settings_mfa
    ).each do |prefix|
      assert helper_names.none? { |name| name.start_with?(prefix) }, "#{prefix} must not exist"
    end
  end

  test "auth org settings keeps only passkey and entra ceremony settings" do
    helper_names = Rails.application.routes.named_routes.helper_names.map(&:to_s)

    %w(
      auth_org_settings
      auth_org_settings_passkey
      auth_org_settings_passkeys_options
      auth_org_settings_passkeys_verification
      auth_org_settings_entra
    ).each do |prefix|
      assert helper_names.any? { |name| name.start_with?(prefix) }, "#{prefix} must remain"
    end

    %w(
      auth_org_settings_totp
      auth_org_settings_google
      auth_org_settings_apple
      auth_org_settings_email
      auth_org_settings_telephone
      auth_org_settings_birthdate
      auth_org_settings_secret
      auth_org_settings_session
      auth_org_settings_revocation
      auth_org_settings_activity
      auth_org_settings_withdrawal
      auth_org_settings_mfa
      auth_org_settings_operator_lifecycle_request
    ).each do |prefix|
      assert helper_names.none? { |name| name.start_with?(prefix) }, "#{prefix} must not exist"
    end
  end

  test "retired auth settings paths are not routable" do
    {
      app: %w(/settings/emails /settings/telephones /settings/birthdate /settings/secret_credentials
              /settings/sessions /settings/revocations/all /settings/activities /settings/withdrawal
              /settings/mfa/challenge /settings/mfa/reset),
      com: %w(/settings/emails /settings/telephones /settings/birthdate /settings/secret_credentials
              /settings/sessions /settings/revocations/all /settings/activities /settings/withdrawal
              /settings/mfa/challenge),
      org: %w(/settings/emails /settings/telephones /settings/birthdate /settings/secret_credentials
              /settings/sessions /settings/revocations/all /settings/activities /settings/withdrawal
              /settings/mfa/challenge /settings/operator_lifecycle_requests),
    }.each do |surface, paths|
      paths.each { |path| assert_unrecognized(surface, path, :get) }
    end
  end

  test "route source excludes sign routing compatibility patterns" do
    source = Rails.root.join("config/routes/auth.rb").read

    forbidden = [
      "safe_sign_state_" + "redirect",
      'scope path: "' + 'sign"',
      "resource :up, only: :show",
      "resource :in, only: :show",
      "resource :out, only: %i(new edit create destroy)",
      'controller: "' + 'sign_ins"',
      'controller: "' + 'sign_outs"',
      'controller: "' + 'checkpoints"',
      "defaults: { preference_" + "screen:",
      "param: :" + "provider",
      'module: "' + 'settings/mfa"',
      "post :" + "continue",
      "post :" + "resend",
    ]

    forbidden.each do |pattern|
      assert_not_includes source, pattern, pattern
    end

    assert_includes source, "scope(module: :auth, as: :auth)"
    assert_includes source, "constraints("
    assert_includes source, "namespace(:social)"
    assert_not_includes source, "namespace(:oidc)"
  end

  private

  def assert_recognizes_sign_route(surface, path, method, controller, action)
    host = SURFACES.fetch(surface)
    route = Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)

    assert_equal controller, route.fetch(:controller)
    assert_equal action, route.fetch(:action)
  end

  def assert_unrecognized(surface, path, method)
    host = SURFACES.fetch(surface)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)
    end
  end
end
