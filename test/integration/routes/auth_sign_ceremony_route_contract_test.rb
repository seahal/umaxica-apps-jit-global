# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthSignCeremonyRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  SIGN_APP_HOST = ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
  SIGN_COM_HOST = ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost")
  SIGN_ORG_HOST = ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost")

  def assert_recognizes(expected, options)
    route = Rails.application.routes.recognize_path(options.fetch(:path), method: options.fetch(:method))

    assert_equal expected.fetch(:controller), route.fetch(:controller)
    assert_equal expected.fetch(:action), route.fetch(:action)
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "auth app route contract" do
    assert_recognizes(
      { controller: "auth/app/roots", action: "index" },
      { path: "http://#{SIGN_APP_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/well_known/jwks", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/healths", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/health/livenesses", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/health/readinesses", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/health/startups", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/robots", action: "index" },
      { path: "http://#{SIGN_APP_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sitemaps", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/outs", action: "new" },
      { path: "http://#{SIGN_APP_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/outs", action: "edit" },
      { path: "http://#{SIGN_APP_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/outs", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/sign/outs", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/sign/out", method: :delete },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sign/out/cancellation", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/oidc/logout", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/oidc/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/oidc/backchannel/logout", method: :post)
    end

    assert_recognizes(
      { controller: "auth/app/csp_violation_reports", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/apple/notifications", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/apple/notifications", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/dashboard", method: :get)
    end

    assert_recognizes(
      { controller: "auth/app/billings", action: "index" },
      { path: "http://#{SIGN_APP_HOST}/billings", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/oidc/callback", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/oidc/authorization", method: :get)
    end

    assert_recognizes(
      { controller: "auth/app/sign/ups", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sign/up", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/apple/confirmations", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/sign/up/check/apple/confirmation", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/apple/birthdates", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/sign/up/check/apple/birthdate", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/email/otps", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/sign/up/check/email/otp", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/email/birthdates", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/sign/up/check/email/birthdate", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/telephone/otps", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/sign/up/check/telephone/otp", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/telephone/passkeys", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/sign/up/check/telephone/passkey", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/telephone/passcodes", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/sign/up/check/telephone/passcode", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/telephone/birthdates", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/sign/up/check/telephone/birthdate", method: :delete },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sign/up/email", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sign/up/check/email/cancellation", method: :post)
    end

    assert_recognizes(
      { controller: "auth/app/sign/ins", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sign/in", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/emails", action: "new" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/email/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/emails", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/email", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/emails", action: "edit" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/email/edit", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/emails", action: "update" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/email", method: :patch },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sign/in/limitation", method: :get)
    end

    ["/sign/up/entrance", "/sign/in/entrance"].each do |bad_path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}#{bad_path}", method: :get)
      end
    end

    assert_recognizes(
      { controller: "auth/app/sign/in/guards", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/guard", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/checks", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/check", method: :get },
    )

    %i(patch delete).each do |method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sign/in/check", method: method)
      end
    end

    assert_recognizes(
      { controller: "auth/app/sign/in/sessions", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/session", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/verification/cancellations", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/challenges", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/challenge", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/passkeys", action: "new" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/passkey/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/passkey/options", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/passkey/options", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/passkey/verifications", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/passkey/verification", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/secrets", action: "new" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/secret/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/secrets", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/sign/in/secret", method: :post },
    )

    [
      { controller: "auth/app/settings", action: "show", path: "/settings" },
      { controller: "auth/app/settings/passkeys", action: "index", path: "/settings/passkeys" },
    ].each do |route|
      assert_recognizes(
        { controller: route[:controller], action: route[:action] },
        { path: "http://#{SIGN_APP_HOST}#{route[:path]}", method: :get },
      )
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  test "auth app-only route contract" do
    %w(
      /social/apple/connection
      /social/apple/disconnection
      /social/google/connection
      /social/google/disconnection
    ).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}#{path}", method: :get)
      end
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}#{path}", method: :post)
      end
    end

    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{SIGN_APP_HOST}/social/google/callback", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/callback", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/social/apple/callback",
        method: :post,
      )
    end

    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "failure" },
      { path: "http://#{SIGN_APP_HOST}/social/failure", method: :get },
    )

    %w(/auth /auth/callback /auth/logout /auth/google_app/callback /auth/apple/callback /auth/failure
       /social/auth/google_app/continue /social/auth/apple/continue).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}#{path}", method: :get)
      end
    end

    # The ceremony is POST only. A GET entry carries no CSRF token, so a link
    # could start it, which is login CSRF.
    %w(google apple).each do |_provider|
      %W(/social/\#{provider}/session /social/\#{provider}/session/new
         /social/\#{provider}/registration /social/\#{provider}/registration/new).each do |_path|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://\#{SIGN_APP_HOST}\#{path}", method: :get)
        end
      end
    end

    assert_recognizes(
      { controller: "auth/app/social/sessions", action: "create", provider: "google", intent: "login" },
      { path: "http://#{SIGN_APP_HOST}/social/google/session", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/social/registrations",
        action: "create",
        provider: "google",
        intent: "login",
        entry: "auth_up", },
      { path: "http://#{SIGN_APP_HOST}/social/google/registration", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/social/sessions", action: "create", provider: "apple", intent: "login" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/session", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/social/registrations",
        action: "create",
        provider: "apple",
        intent: "login",
        entry: "auth_up", },
      { path: "http://#{SIGN_APP_HOST}/social/apple/registration", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{SIGN_APP_HOST}/social/google/callback", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{SIGN_APP_HOST}/social/apple/callback", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/social/apple/callback",
        method: :post,
      )
    end

    assert_recognizes(
      { controller: "auth/app/settings/totps", action: "index" },
      { path: "http://#{SIGN_APP_HOST}/settings/totps", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/settings/apples", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/settings/apple", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/settings/apples", action: "edit" },
      { path: "http://#{SIGN_APP_HOST}/settings/apple/edit", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/settings/apples", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/settings/apple", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/settings/apples", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/settings/apple", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/settings/googles", action: "show" },
      { path: "http://#{SIGN_APP_HOST}/settings/google", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/settings/googles", action: "edit" },
      { path: "http://#{SIGN_APP_HOST}/settings/google/edit", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/settings/googles", action: "create" },
      { path: "http://#{SIGN_APP_HOST}/settings/google", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/settings/googles", action: "destroy" },
      { path: "http://#{SIGN_APP_HOST}/settings/google", method: :delete },
    )

    %w(/settings/apple /settings/google).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}#{path}", method: :patch)
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/settings/secret_credentials",
        method: :get,
      )
    end
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "auth com route contract" do
    assert_recognizes(
      { controller: "auth/com/roots", action: "index" },
      { path: "http://#{SIGN_COM_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/well_known/jwks", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/healths", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/health/livenesses", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/health/readinesses", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/health/startups", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/robots", action: "index" },
      { path: "http://#{SIGN_COM_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sitemaps", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sign/outs", action: "new" },
      { path: "http://#{SIGN_COM_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sign/outs", action: "edit" },
      { path: "http://#{SIGN_COM_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sign/outs", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "auth/com/sign/outs", action: "destroy" },
      { path: "http://#{SIGN_COM_HOST}/sign/out", method: :delete },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/sign/out/cancellation", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/oidc/logout", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/oidc/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/oidc/backchannel/logout", method: :post)
    end

    assert_recognizes(
      { controller: "auth/com/csp_violation_reports", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/csp-violation-report", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/dashboard", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/oidc/callback", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/oidc/authorization", method: :get)
    end

    assert_recognizes(
      { controller: "auth/com/sign/ups", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sign/up", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sign/up/check/email/otps", action: "destroy" },
      { path: "http://#{SIGN_COM_HOST}/sign/up/check/email/otp", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/com/sign/up/check/email/birthdates", action: "destroy" },
      { path: "http://#{SIGN_COM_HOST}/sign/up/check/email/birthdate", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/com/sign/up/check/telephone/otps", action: "destroy" },
      { path: "http://#{SIGN_COM_HOST}/sign/up/check/telephone/otp", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/com/sign/up/check/telephone/passkeys", action: "destroy" },
      { path: "http://#{SIGN_COM_HOST}/sign/up/check/telephone/passkey", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/com/sign/up/check/telephone/passcodes", action: "destroy" },
      { path: "http://#{SIGN_COM_HOST}/sign/up/check/telephone/passcode", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/com/sign/up/check/telephone/birthdates", action: "destroy" },
      { path: "http://#{SIGN_COM_HOST}/sign/up/check/telephone/birthdate", method: :delete },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/sign/up/email", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/sign/up/check/email/cancellation", method: :post)
    end

    assert_recognizes(
      { controller: "auth/com/sign/ins", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sign/in", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sign/in/emails", action: "new" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/email/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sign/in/emails", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/email", method: :post },
    )

    assert_recognizes(
      { controller: "auth/com/sign/in/emails", action: "edit" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/email/edit", method: :get },
    )

    ["/sign/up/entrance", "/sign/in/entrance"].each do |bad_path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}#{bad_path}", method: :get)
      end
    end

    assert_recognizes(
      { controller: "auth/com/sign/in/guards", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/guard", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sign/in/checks", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/check", method: :get },
    )

    %i(patch delete).each do |method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_COM_HOST}/sign/in/check", method: method)
      end
    end

    assert_recognizes(
      { controller: "auth/com/sign/in/sessions", action: "destroy" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/session", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/com/verification/cancellations", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "auth/com/sign/in/challenges", action: "show" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/challenge", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sign/in/passkeys", action: "new" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/passkey/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sign/in/passkey/options", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/passkey/options", method: :post },
    )

    assert_recognizes(
      { controller: "auth/com/sign/in/passkey/verifications", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/passkey/verification", method: :post },
    )

    assert_recognizes(
      { controller: "auth/com/sign/in/secrets", action: "new" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/secret/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/com/sign/in/secrets", action: "create" },
      { path: "http://#{SIGN_COM_HOST}/sign/in/secret", method: :post },
    )

    [
      { controller: "auth/com/settings", action: "show", path: "/settings" },
      { controller: "auth/com/settings/passkeys", action: "index", path: "/settings/passkeys" },
    ].each do |route|
      assert_recognizes(
        { controller: route[:controller], action: route[:action] },
        { path: "http://#{SIGN_COM_HOST}#{route[:path]}", method: :get },
      )
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "auth org route contract" do
    assert_recognizes(
      { controller: "auth/org/roots", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/well_known/jwks", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/healths", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/health/livenesses", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/health/readinesses", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/health/startups", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/robots", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sitemaps", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sign/outs", action: "new" },
      { path: "http://#{SIGN_ORG_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sign/outs", action: "edit" },
      { path: "http://#{SIGN_ORG_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sign/outs", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "auth/org/sign/outs", action: "destroy" },
      { path: "http://#{SIGN_ORG_HOST}/sign/out", method: :delete },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/sign/out/cancellation", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/oidc/logout", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/oidc/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/oidc/backchannel/logout", method: :post)
    end

    assert_recognizes(
      { controller: "auth/org/csp_violation_reports", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/csp-violation-report", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/dashboard", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/oidc/callback", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/oidc/authorization", method: :get)
    end

    assert_recognizes(
      { controller: "auth/org/sign/ups", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sign/up", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/sign/up/email", method: :get)
    end

    assert_recognizes(
      { controller: "auth/org/sign/ins", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sign/up/invitations", action: "new" },
      { path: "http://#{SIGN_ORG_HOST}/sign/up/invitations/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sign/up/invitations", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/up/invitations", method: :post },
    )

    ["/sign/up/entrance", "/sign/in/entrance"].each do |bad_path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}#{bad_path}", method: :get)
      end
    end

    assert_recognizes(
      { controller: "auth/org/sign/in/guards", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/guard", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sign/in/checks", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/check", method: :get },
    )

    %i(patch delete).each do |method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}/sign/in/check", method: method)
      end
    end

    assert_recognizes(
      { controller: "auth/org/sign/in/sessions", action: "destroy" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/session", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/org/verification/cancellations", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "auth/org/sign/in/challenges", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/challenge", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sign/in/passkeys", action: "new" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/passkey/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sign/in/passkey/options", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/passkey/options", method: :post },
    )

    assert_recognizes(
      { controller: "auth/org/sign/in/passkey/verifications", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/passkey/verification", method: :post },
    )

    assert_recognizes(
      { controller: "auth/org/sign/in/secrets", action: "new" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/secret/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sign/in/secrets", action: "create" },
      { path: "http://#{SIGN_ORG_HOST}/sign/in/secret", method: :post },
    )

    # Entra sign-in ceremony start. Sign-in only: the org surface has no social
    # registration counterpart to the app surface's social/*/registration.
    assert_recognizes(
      { controller: "auth/org/social/sessions", action: "new", provider: "entra" },
      { path: "http://#{SIGN_ORG_HOST}/social/entra/session/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/social/sessions", action: "create", provider: "entra" },
      { path: "http://#{SIGN_ORG_HOST}/social/entra/session", method: :post },
    )

    %w(/social/entra/registration /social/entra/registration/new).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}#{path}", method: :get)
      end
    end
  end

  test "auth org route contract (continued)" do
    assert_recognizes(
      { controller: "auth/org/settings", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/settings", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/settings/passkeys", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/settings/passkeys", method: :get },
    )

    %w(/settings/sessions /settings/activities).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{SIGN_ORG_HOST}#{path}", method: :get)
      end
    end

    assert_recognizes(
      { controller: "auth/org/configurations", action: "show" },
      { path: "http://#{SIGN_ORG_HOST}/configuration", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/accounts", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/accounts", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/iam", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/iam", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/system", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/system", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/audit", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/audit", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/support", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/support", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/billing", action: "index" },
      { path: "http://#{SIGN_ORG_HOST}/billing", method: :get },
    )
  end

  test "auth negative route contract" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/sso/authorize",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/social/apple/session/new",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/auth/acme",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/auth/acme/callback",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/sso/authorize",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/sso/logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/auth/acme",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/auth/acme/callback",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/sso/authorize",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/sso/logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/auth/acme",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/auth/acme/callback",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/oidc/backchannel_logout",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_ORG_HOST}/oidc/frontchannel_logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_APP_HOST}/accounts",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{SIGN_COM_HOST}/accounts",
        method: :get,
      )
    end

    # The secret credential sign-in path is `/sign/in/secret`; the former
    # `/sign/in/secret_credential` spelling is retired with no compatibility redirect.
    [SIGN_APP_HOST, SIGN_COM_HOST, SIGN_ORG_HOST].each do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{host}/sign/in/secret_credential/new",
          method: :get,
        )
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{host}/sign/in/secret_credential",
          method: :post,
        )
      end
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  test "auth remains a relying party and does not expose oauth provider endpoints" do
    [SIGN_APP_HOST, SIGN_COM_HOST, SIGN_ORG_HOST].each do |host|
      %w(/authorize /token /userinfo /jwks /oauth/authorize /oauth/token /oauth/userinfo /oauth/jwks).each do |path|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
        end
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/oauth/token", method: :post)
      end
    end
  end
end
