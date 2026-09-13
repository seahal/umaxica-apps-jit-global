# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseAuthorityRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BASE_APP_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  BASE_COM_HOST = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
  BASE_ORG_HOST = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")

  test "base authority routes accept internal origin and cloudflared public hosts" do
    {
      "base.app.localhost" => "base/app/roots",
      "base.com.localhost" => "base/com/roots",
      "base.org.localhost" => "base/org/roots",
      "www.umaxica.app" => "base/app/roots",
      "www.umaxica.com" => "base/com/roots",
      "www.umaxica.org" => "base/org/roots",
    }.each do |host, controller|
      assert_recognizes(
        { controller: controller, action: "index" },
        { path: "http://#{host}/", method: :get },
      )
    end
  end

  test "base authority app static and health routes" do
    assert_recognizes(
      { controller: "base/app/roots", action: "index" },
      { path: "http://#{BASE_APP_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/well_known/jwks", action: "show" },
      { path: "http://#{BASE_APP_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/well_known/discoveries", action: "show" },
      { path: "http://#{BASE_APP_HOST}/.well-known/openid-configuration", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/healths", action: "show" },
      { path: "http://#{BASE_APP_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/health/livenesses", action: "show" },
      { path: "http://#{BASE_APP_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/health/readinesses", action: "show" },
      { path: "http://#{BASE_APP_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/health/startups", action: "show" },
      { path: "http://#{BASE_APP_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/robots", action: "index" },
      { path: "http://#{BASE_APP_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/sitemaps", action: "show" },
      { path: "http://#{BASE_APP_HOST}/sitemap.xml", method: :get },
    )
  end

  test "base authority app auth routes" do
    assert_recognizes(
      { controller: "base/app/csp_violation_reports", action: "create" },
      { path: "http://#{BASE_APP_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "base/app/welcomes", action: "show" },
      { path: "http://#{BASE_APP_HOST}/welcome", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/dashboards", action: "show" },
      { path: "http://#{BASE_APP_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/verification/cancellations", action: "create" },
      { path: "http://#{BASE_APP_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "base/app/selectors", action: "show" },
      { path: "http://#{BASE_APP_HOST}/selector", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/selectors", action: "update" },
      { path: "http://#{BASE_APP_HOST}/selector", method: :patch },
    )

    assert_recognizes(
      { controller: "base/app/switchers", action: "show" },
      { path: "http://#{BASE_APP_HOST}/switcher", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/switchers", action: "update" },
      { path: "http://#{BASE_APP_HOST}/switcher", method: :patch },
    )

    assert_recognizes(
      { controller: "base/app/sign/in/limitations", action: "show" },
      { path: "http://#{BASE_APP_HOST}/sign/in/limitation", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/sign/in/limitations", action: "update" },
      { path: "http://#{BASE_APP_HOST}/sign/in/limitation", method: :patch },
    )

    assert_recognizes(
      { controller: "base/app/sign/in/limitations", action: "update" },
      { path: "http://#{BASE_APP_HOST}/sign/in/limitation", method: :put },
    )

    assert_recognizes(
      { controller: "base/app/sign/in/limitations", action: "destroy" },
      { path: "http://#{BASE_APP_HOST}/sign/in/limitation", method: :delete },
    )

    assert_recognizes(
      { controller: "base/app/oidc/callbacks", action: "show" },
      { path: "http://#{BASE_APP_HOST}/oidc/callback", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/oidc/authorizations", action: "show" },
      { path: "http://#{BASE_APP_HOST}/oidc/authorization", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/sign_outs", action: "new" },
      { path: "http://#{BASE_APP_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/sign_outs", action: "edit" },
      { path: "http://#{BASE_APP_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/sign_outs", action: "create" },
      { path: "http://#{BASE_APP_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "base/app/lobbies", action: "show" },
      { path: "http://#{BASE_APP_HOST}/lobby", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/sign/out", method: :delete)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/sso/authorize", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/sso/logout", method: :post)
    end

    assert_recognizes(
      { controller: "base/app/oidc/logouts", action: "show" },
      { path: "http://#{BASE_APP_HOST}/oidc/logout", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/oidc/logouts", action: "create" },
      { path: "http://#{BASE_APP_HOST}/oidc/logout", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/oidc/logout", method: :delete)
    end
  end

  test "base authority app oauth and account routes" do
    assert_recognizes(
      { controller: "base/app/oauth/authorizations", action: "show" },
      { path: "http://#{BASE_APP_HOST}/oauth/authorize", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/oauth/tokens", action: "create" },
      { path: "http://#{BASE_APP_HOST}/oauth/token", method: :post },
    )

    assert_recognizes(
      { controller: "base/app/oauth/userinfos", action: "show" },
      { path: "http://#{BASE_APP_HOST}/oauth/userinfo", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/oauth/revocations", action: "create" },
      { path: "http://#{BASE_APP_HOST}/oauth/revoke", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/oauth/jwks", method: :get)
    end

    %w(/auth /auth/callback /auth/logout /oauth/callback /oauth/jwks /social/auth/google_app/continue
       /social/auth/google_app/completion).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}#{path}", method: :get)
      end
    end

    # Entity CRUD is plural; current-context display/switching lives at /switcher. The abandoned
    # /current/* namespace must not resolve on the app surface.
    [
      { path: "/current/organization", method: :get },
      { path: "/current/organization/edit", method: :get },
      { path: "/current/organization", method: :patch },
      { path: "/current/avatar", method: :get },
      { path: "/current/avatar/edit", method: :get },
      { path: "/current/avatar", method: :patch },
      { path: "/current/avatar", method: :delete },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_APP_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end
  end

  test "base authority app singular current routes do not resolve" do
    # Singular current routes are intentionally absent; selection and switching stay on
    # /selector and /switcher, while CRUD remains pluralized.
    [
      { path: "/account", method: :get },
      { path: "/account/edit", method: :get },
      { path: "/account", method: :patch },
      { path: "/organization", method: :get },
      { path: "/organization/edit", method: :get },
      { path: "/organization", method: :patch },
      { path: "/avatar", method: :get },
      { path: "/avatar/edit", method: :get },
      { path: "/avatar", method: :patch },
      { path: "/avatar", method: :delete },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_APP_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    {
      index: { path: "/avatars", method: :get },
      new: { path: "/avatars/new", method: :get },
      create: { path: "/avatars", method: :post },
      show: { path: "/avatars/example", method: :get, id: "example" },
      edit: { path: "/avatars/example/edit", method: :get, id: "example" },
      update: { path: "/avatars/example", method: :patch, id: "example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/app/avatars", action: action.to_s, id: opts[:id] }.compact,
        { path: "http://#{BASE_APP_HOST}#{opts[:path]}", method: opts[:method], id: opts[:id] }.compact,
      )
    end

    # Avatars are not destroyable from this surface.
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/avatars/example", method: :delete)
    end

    {
      index: { path: "/organizations" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/app/organizations", action: action.to_s },
        { path: "http://#{BASE_APP_HOST}#{opts[:path]}", method: :get },
      )
    end

    assert_recognizes(
      { controller: "base/app/organizations", action: "show", id: "example" },
      { path: "http://#{BASE_APP_HOST}/organizations/example", method: :get, id: "example" },
    )

    {
      index: { method: :get, path: "/organizations/example/memberships" },
      new: { method: :get, path: "/organizations/example/memberships/new" },
      create: { method: :post, path: "/organizations/example/memberships" },
      edit: { method: :get, path: "/organizations/example/memberships/member-example/edit", id: "member-example" },
      update: { method: :patch, path: "/organizations/example/memberships/member-example", id: "member-example" },
      destroy: { method: :delete, path: "/organizations/example/memberships/member-example", id: "member-example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/app/organizations/memberships",
          action: action.to_s,
          organization_id: "example",
          id: opts[:id], }.compact,
        { path: "http://#{BASE_APP_HOST}#{opts[:path]}",
          method: opts[:method],
          organization_id: "example",
          id: opts[:id], }.compact,
      )
    end

    {
      index: { path: "/accounts", method: :get },
      show: { path: "/accounts/example", method: :get, id: "example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/app/accounts", action: action.to_s, id: opts[:id] }.compact,
        { path: "http://#{BASE_APP_HOST}#{opts[:path]}", method: opts[:method], id: opts[:id] }.compact,
      )
    end

    assert_recognizes(
      { controller: "base/app/identities", action: "show" },
      { path: "http://#{BASE_APP_HOST}/identity", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/preferences", action: "show" },
      { path: "http://#{BASE_APP_HOST}/preference", method: :get },
    )

    {
      region: %w(edit patch),
      timezone: %w(edit patch),
      language: %w(edit patch),
      currency: %w(edit patch),
      calendar: %w(edit patch),
      clock: %w(edit patch),
      motion: %w(edit patch),
      density: %w(edit patch),
      pagination: %w(edit patch),
      theme: %w(edit patch),
      cookie: %w(edit patch),
    }.each do |name, (edit_action, _update_verb)|
      assert_recognizes(
        { controller: "base/app/preference/#{name.to_s.pluralize}", action: edit_action },
        { path: "http://#{BASE_APP_HOST}/preference/#{name}/edit", method: :get },
      )

      assert_recognizes(
        { controller: "base/app/preference/#{name.to_s.pluralize}", action: "update" },
        { path: "http://#{BASE_APP_HOST}/preference/#{name}", method: :patch },
      )
    end

    assert_recognizes(
      { controller: "base/app/preference/customizations", action: "edit" },
      { path: "http://#{BASE_APP_HOST}/preference/customization/edit", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/preference/customizations", action: "destroy" },
      { path: "http://#{BASE_APP_HOST}/preference/customization", method: :delete },
    )

    assert_recognizes(
      { controller: "base/app/preference/emails", action: "edit", id: "example" },
      { path: "http://#{BASE_APP_HOST}/preference/emails/example/edit", method: :get },
    )

    assert_recognizes(
      { controller: "base/app/preference/emails", action: "destroy", id: "example" },
      { path: "http://#{BASE_APP_HOST}/preference/emails/example", method: :delete },
    )

    assert_recognizes(
      { controller: "base/app/preference/emails", action: "create", id: "example" },
      { path: "http://#{BASE_APP_HOST}/preference/emails/example", method: :post },
    )

    %w(date time page_size).each do |name|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/preference/#{name}/edit", method: :get)
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{BASE_APP_HOST}/preference/#{name}", method: :patch)
      end
    end
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "base authority com route contract" do
    assert_recognizes(
      { controller: "base/com/roots", action: "index" },
      { path: "http://#{BASE_COM_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/well_known/jwks", action: "show" },
      { path: "http://#{BASE_COM_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/well_known/discoveries", action: "show" },
      { path: "http://#{BASE_COM_HOST}/.well-known/openid-configuration", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/healths", action: "show" },
      { path: "http://#{BASE_COM_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/health/livenesses", action: "show" },
      { path: "http://#{BASE_COM_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/health/readinesses", action: "show" },
      { path: "http://#{BASE_COM_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/health/startups", action: "show" },
      { path: "http://#{BASE_COM_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/robots", action: "index" },
      { path: "http://#{BASE_COM_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/sitemaps", action: "show" },
      { path: "http://#{BASE_COM_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/csp_violation_reports", action: "create" },
      { path: "http://#{BASE_COM_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "base/com/welcomes", action: "show" },
      { path: "http://#{BASE_COM_HOST}/welcome", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/dashboards", action: "show" },
      { path: "http://#{BASE_COM_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/verification/cancellations", action: "create" },
      { path: "http://#{BASE_COM_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "base/com/selectors", action: "show" },
      { path: "http://#{BASE_COM_HOST}/selector", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/selectors", action: "update" },
      { path: "http://#{BASE_COM_HOST}/selector", method: :patch },
    )

    assert_recognizes(
      { controller: "base/com/switchers", action: "show" },
      { path: "http://#{BASE_COM_HOST}/switcher", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/switchers", action: "update" },
      { path: "http://#{BASE_COM_HOST}/switcher", method: :patch },
    )

    assert_recognizes(
      { controller: "base/com/oidc/callbacks", action: "show" },
      { path: "http://#{BASE_COM_HOST}/oidc/callback", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/oidc/authorizations", action: "show" },
      { path: "http://#{BASE_COM_HOST}/oidc/authorization", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/sign_outs", action: "new" },
      { path: "http://#{BASE_COM_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/sign_outs", action: "edit" },
      { path: "http://#{BASE_COM_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/sign_outs", action: "create" },
      { path: "http://#{BASE_COM_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "base/com/lobbies", action: "show" },
      { path: "http://#{BASE_COM_HOST}/lobby", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/sign/out", method: :delete)
    end

    [
      { path: "/sso/authorize", method: :get },
      { path: "/sso/logout", method: :post },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_COM_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    assert_recognizes(
      { controller: "base/com/oidc/logouts", action: "show" },
      { path: "http://#{BASE_COM_HOST}/oidc/logout", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/oidc/logouts", action: "create" },
      { path: "http://#{BASE_COM_HOST}/oidc/logout", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_COM_HOST}/oidc/logout", method: :delete)
    end

    assert_recognizes(
      { controller: "base/com/oauth/authorizations", action: "show" },
      { path: "http://#{BASE_COM_HOST}/oauth/authorize", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/oauth/tokens", action: "create" },
      { path: "http://#{BASE_COM_HOST}/oauth/token", method: :post },
    )

    assert_recognizes(
      { controller: "base/com/oauth/userinfos", action: "show" },
      { path: "http://#{BASE_COM_HOST}/oauth/userinfo", method: :get },
    )

    assert_recognizes(
      { controller: "base/com/oauth/revocations", action: "create" },
      { path: "http://#{BASE_COM_HOST}/oauth/revoke", method: :post },
    )

    {
      index: { path: "/accounts", method: :get },
      show: { path: "/accounts/example", method: :get, id: "example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/com/accounts", action: action.to_s, id: opts[:id] }.compact,
        { path: "http://#{BASE_COM_HOST}#{opts[:path]}", method: opts[:method], id: opts[:id] }.compact,
      )
    end

    [
      { path: "/account", method: :get },
      { path: "/account/edit", method: :get },
      { path: "/account", method: :patch },
      { path: "/current/organization", method: :get },
      { path: "/current/organization/edit", method: :get },
      { path: "/current/organization", method: :patch },
      { path: "/organization", method: :get },
      { path: "/organization/edit", method: :get },
      { path: "/organization", method: :patch },
      { path: "/current/avatar", method: :get },
      { path: "/current/avatar/edit", method: :get },
      { path: "/current/avatar", method: :patch },
      { path: "/current/avatar", method: :delete },
      { path: "/avatar", method: :get },
      { path: "/avatar/edit", method: :get },
      { path: "/avatar", method: :patch },
      { path: "/avatar", method: :delete },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_COM_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    {
      index: { path: "/organizations" },
      show: { path: "/organizations/example", id: "example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/com/organizations", action: action.to_s, id: opts[:id] }.compact,
        { path: "http://#{BASE_COM_HOST}#{opts[:path]}", method: :get, id: opts[:id] }.compact,
      )
    end

    assert_recognizes(
      { controller: "base/com/organizations/memberships", action: "index", organization_id: "example" },
      { path: "http://#{BASE_COM_HOST}/organizations/example/memberships", method: :get, organization_id: "example" },
    )

    assert_recognizes(
      { controller: "base/com/identities", action: "show" },
      { path: "http://#{BASE_COM_HOST}/identity", method: :get },
    )

    # NOTE: /settings is omitted -- recognize_path does not enforce host constraints;
    # side/com/settings bleeds through. Integration tests cover the actual host boundary.
  end
  # rubocop:enable Minitest/MultipleAssertions

  test "base authority org route contract" do
    assert_recognizes(
      { controller: "base/org/roots", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/well_known/jwks", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/healths", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/health/livenesses", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/health/readinesses", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/health/startups", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/robots", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/sitemaps", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/sitemap.xml", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/csp_violation_reports", action: "create" },
      { path: "http://#{BASE_ORG_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "base/org/welcomes", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/welcome", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/dashboards", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/dashboard", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/verification/cancellations", action: "create" },
      { path: "http://#{BASE_ORG_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "base/org/selectors", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/selector", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/selectors", action: "update" },
      { path: "http://#{BASE_ORG_HOST}/selector", method: :patch },
    )

    assert_recognizes(
      { controller: "base/org/switchers", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/switcher", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/switchers", action: "update" },
      { path: "http://#{BASE_ORG_HOST}/switcher", method: :patch },
    )

    assert_recognizes(
      { controller: "base/org/oidc/callbacks", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/oidc/callback", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/oidc/authorizations", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/oidc/authorization", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/sign_outs", action: "new" },
      { path: "http://#{BASE_ORG_HOST}/sign/out/new", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/sign_outs", action: "edit" },
      { path: "http://#{BASE_ORG_HOST}/sign/out/edit", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/sign_outs", action: "create" },
      { path: "http://#{BASE_ORG_HOST}/sign/out", method: :post },
    )

    assert_recognizes(
      { controller: "base/org/lobbies", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/lobby", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/sign/out", method: :delete)
    end
  end

  test "base authority org route contract (continued)" do
    [
      { path: "/sso/authorize", method: :get },
      { path: "/sso/logout", method: :post },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_ORG_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    assert_recognizes(
      { controller: "base/org/oidc/logouts", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/oidc/logout", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/oidc/logouts", action: "create" },
      { path: "http://#{BASE_ORG_HOST}/oidc/logout", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/oidc/logout", method: :delete)
    end

    assert_recognizes(
      { controller: "base/org/oauth/authorizations", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/oauth/authorize", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/oauth/tokens", action: "create" },
      { path: "http://#{BASE_ORG_HOST}/oauth/token", method: :post },
    )

    assert_recognizes(
      { controller: "base/org/oauth/userinfos", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/oauth/userinfo", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/oauth/revocations", action: "create" },
      { path: "http://#{BASE_ORG_HOST}/oauth/revoke", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/organization", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/organization/edit", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/organization", method: :patch)
    end

    [
      { path: "/account", method: :get },
      { path: "/account/edit", method: :get },
      { path: "/account", method: :patch },
      { path: "/organization", method: :get },
      { path: "/organization/edit", method: :get },
      { path: "/organization", method: :patch },
    ].each do |bad_route|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{BASE_ORG_HOST}#{bad_route[:path]}",
          method: bad_route[:method],
        )
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/avatar", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/avatar/edit", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/avatar", method: :patch)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{BASE_ORG_HOST}/current/avatar", method: :delete)
    end

    assert_recognizes(
      { controller: "base/org/avatars", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/avatar", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/avatars", action: "edit" },
      { path: "http://#{BASE_ORG_HOST}/avatar/edit", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/avatars", action: "update" },
      { path: "http://#{BASE_ORG_HOST}/avatar", method: :patch },
    )

    assert_recognizes(
      { controller: "base/org/avatars", action: "destroy" },
      { path: "http://#{BASE_ORG_HOST}/avatar", method: :delete },
    )

    {
      index: { path: "/organizations" },
      show: { path: "/organizations/example", id: "example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/org/organizations", action: action.to_s, id: opts[:id] }.compact,
        { path: "http://#{BASE_ORG_HOST}#{opts[:path]}", method: :get, id: opts[:id] }.compact,
      )
    end

    assert_recognizes(
      { controller: "base/org/organizations/memberships",
        action: "destroy",
        organization_id: "example",
        id: "member-example", },
      { path: "http://#{BASE_ORG_HOST}/organizations/example/memberships/member-example",
        method: :delete,
        organization_id: "example",
        id: "member-example", },
    )

    {
      index: { path: "/accounts", method: :get },
      show: { path: "/accounts/example", method: :get, id: "example" },
    }.each do |action, opts|
      assert_recognizes(
        { controller: "base/org/accounts", action: action.to_s, id: opts[:id] }.compact,
        { path: "http://#{BASE_ORG_HOST}#{opts[:path]}", method: opts[:method], id: opts[:id] }.compact,
      )
    end

    assert_recognizes(
      { controller: "base/org/configurations", action: "show" },
      { path: "http://#{BASE_ORG_HOST}/configuration", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/iam", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/iam", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/system", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/system", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/audit", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/audit", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/support", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/support", method: :get },
    )

    assert_recognizes(
      { controller: "base/org/billing", action: "index" },
      { path: "http://#{BASE_ORG_HOST}/billing", method: :get },
    )

    # NOTE: /settings is omitted -- recognize_path does not enforce host constraints;
    # side/org/settings bleeds through. Integration tests cover the actual host boundary.
  end

  test "base authority settings routes are retired" do
    {
      BASE_APP_HOST => "app",
      BASE_COM_HOST => "com",
      BASE_ORG_HOST => "org",
    }.each_key do |host|
      [
        # NOTE: /settings (bare) is intentionally excluded -- recognize_path does not enforce host
        # constraints, so side/*/settings routes bleed through. The actual host constraint is
        # verified by integration tests that make real HTTP requests.
        { path: "/settings/secrets", method: :get },
        { path: "/settings/secrets/enrollment", method: :post },
        { path: "/settings/secrets/secret-example/edit", method: :get },
        { path: "/settings/secrets/secret-example", method: :delete },
        { path: "/settings/secret_credentials", method: :get },
      ].each do |route|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{host}#{route.fetch(:path)}", method: route.fetch(:method))
        end
      end
    end
  end

  test "base authority retired routes do not resolve" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{BASE_APP_HOST}/oauth/user_info",
        method: :get,
      )
    end

    # NOTE: /accounts resolves on all three Base authority surfaces as entity CRUD.

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{BASE_APP_HOST}/auth/acme",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{BASE_APP_HOST}/auth/acme/callback",
        method: :get,
      )
    end
  end
end
