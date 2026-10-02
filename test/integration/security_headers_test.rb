# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "production-like ssl middleware emits conservative hsts header" do
    app = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["OK"]] }
    ssl = ActionDispatch::SSL.new(
      app,
      hsts: {
        expires: 365.days,
        subdomains: false,
        preload: false,
      },
    )

    response = Rack::MockRequest.new(ssl).get("https://example.test/health")

    assert_equal "max-age=31536000", response["Strict-Transport-Security"]
  end

  test "content security policy and permissions policy are enforced" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL")

    get sign_app_health_liveness_url(ri: "jp")

    assert_response :success
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
    assert_includes response.headers["Content-Security-Policy"], "default-src 'self'"
    assert_includes response.headers["Content-Security-Policy"], "object-src 'none'"
    # Every external identity provider the browser is navigated to by a form submission has to be
    # named. login.microsoftonline.com is the org-surface Entra ceremony target: the POST to
    # /social/entra redirects there, and Firefox applies form-action to that redirect.
    assert_includes response.headers["Content-Security-Policy"],
                    "form-action 'self' https://accounts.google.com https://appleid.apple.com " \
                    "https://login.microsoftonline.com"
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)

    assert_includes response.headers["Content-Security-Policy"], "https://#{hosts.base_service.host}"
    assert_includes response.headers["Content-Security-Policy"], "https://#{hosts.base_corporate.host}"
    assert_includes response.headers["Content-Security-Policy"], "https://#{hosts.base_staff.host}"
    assert_includes response.headers["Content-Security-Policy"], "https://#{hosts.auth_service.host}"
    # The configured Auth origin has to be the public one the browser uses. The social
    # ceremony posts from Auth to Base and Base redirects back to Auth; Firefox applies
    # form-action to that redirect, so a stale Auth origin here blocks the handoff.
    assert_includes response.headers["Content-Security-Policy"],
                    "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}"
    # Internal hosts must never be form-action targets: browser-posted forms have to
    # aim at the public origins asserted above.
    assert_not_includes response.headers["Content-Security-Policy"],
                        ENV.fetch("PRIVATE_BASE_SERVICE_URL")
    # The jump gateway must be a valid form-action target: sign-flow form submissions
    # (e.g. the sign-up birthdate checkpoint) finalize by redirecting through it.
    assert_includes response.headers["Content-Security-Policy"],
                    Rails.configuration.x.boot_config.fetch(:jump).origin
    # connect-src decides where injected script may send data, so it must name
    # origins rather than the `https:` scheme. `https:` permits every HTTPS host
    # on the internet and removes CSP's value as an exfiltration control.
    assert_includes response.headers["Content-Security-Policy"],
                    "connect-src 'self' https://challenges.cloudflare.com"
    assert_no_match(
      /connect-src[^;]*\s(?:https:|ws:|wss:)(?:\s|;|$)/,
      response.headers["Content-Security-Policy"],
    )
    assert_includes response.headers["Content-Security-Policy"], "script-src 'self' 'strict-dynamic'"
    assert_not_includes response.headers["Content-Security-Policy"], "script-src-elem"
    assert_includes response.headers["Content-Security-Policy"], "https://challenges.cloudflare.com"
    assert_no_match(/script-src[^;]*\shttps:(?:\s|;|$)/, response.headers["Content-Security-Policy"])
    assert_not_includes response.headers["Content-Security-Policy"], "'unsafe-inline'"
    assert_equal "credentialless", response.headers["Cross-Origin-Embedder-Policy"]
    assert_equal "same-origin", response.headers["Cross-Origin-Opener-Policy"]
    assert_equal "same-origin", response.headers["Cross-Origin-Resource-Policy"]
    assert_nil response.headers["Feature-Policy"]
    assert_includes response.headers["Permissions-Policy"], "camera=()"
    assert_includes response.headers["Permissions-Policy"], "geolocation=()"
    assert_includes response.headers["Permissions-Policy"], "microphone=()"
    assert_includes response.headers["Permissions-Policy"], "publickey-credentials-get=(self)"
    assert_not_includes response.headers["Permissions-Policy"], "bluetooth"
    assert_not_includes response.headers["Permissions-Policy"], "publickey-credentials-create"
    assert_no_match(/,\s+/, response.headers["Permissions-Policy"])
  end

  # Rails resolves a dynamic CSP source with `context.instance_exec`, where the context is
  # `request.controller_instance || request`. Only the controller answers `request`, so a lambda
  # that calls it raises NameError while building the header for every response no controller
  # handled: an exception page, a middleware reply, a static file. The one lambda that needs the
  # host is development-only, so no request in this suite reaches it; this reads the initializer
  # instead.
  test "dynamic content security policy sources do not assume a controller context" do
    initializer = Rails.root.join("config/initializers/content_security_policy.rb").read
    sources = initializer.scan(/->\s*\{[^}]*\}/)

    assert_predicate sources, :any?, "expected the policy to declare dynamic sources"

    sources.grep(/\brequest\b/).each do |source|
      assert_includes source, "respond_to?(:request)",
                      "#{source.strip} must resolve the request for both context types"
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class SecurityHeadersTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
