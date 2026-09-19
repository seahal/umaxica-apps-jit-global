# typed: false
# frozen_string_literal: true

require "test_helper"

# Authenticated pages must not outlive the session in a browser: an authenticated HTML or Inertia
# response is `Cache-Control: no-store` (so neither the HTTP cache nor the back/forward cache keeps
# it), and a response that ends a session tells Inertia to clear its encrypted history. Public
# pages and JSON endpoints keep their existing cache behavior, and ordinary authenticated
# navigation does not clear history.
class AuthenticatedResponseCachePolicyTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_service)
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    bootstrap_and_select!(@user, @token)
  end

  test "an authenticated HTML page is no-store" do
    get base_app_accounts_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_no_store
  end

  test "an authenticated Inertia visit is no-store" do
    get base_app_accounts_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)
    version = inertia_page.fetch("version")

    get base_app_accounts_url(ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host).merge("X-Inertia" => "true", "X-Inertia-Version" => version.to_s)

    assert_response :success
    assert_equal "true", response.headers["X-Inertia"]
    assert_no_store
  end

  test "ordinary authenticated navigation does not clear Inertia history" do
    get base_app_accounts_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_not inertia_page.fetch("clearHistory")
  end

  test "a public HTML page keeps its cache behavior" do
    get edit_base_app_preference_cookie_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_not_includes response.headers["Cache-Control"].to_s, "no-store"
  end

  test "an open page answered for a signed-in user is no-store" do
    get edit_base_app_preference_cookie_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_no_store
  end

  test "an authenticated JSON response is left alone" do
    get base_app_selector_url(ri: "jp", host: @host, format: :json), headers: as_user_headers(@user, host: @host)

    assert_equal "application/json", response.media_type
    assert_not_includes response.headers["Cache-Control"].to_s, "no-store"
  end

  test "signing out clears Inertia history on the signed-out page" do
    headers = as_user_headers(@user, host: @host)
    post base_app_sign_out_url(ri: "jp", host: @host), headers: headers
    follow_redirect!(headers: host_headers(@host)) while response.redirect? && same_host?(response.location)

    assert_response :success
    assert inertia_page.fetch("clearHistory")
  end

  # Stale credentials on an :open page are detached and the request continues anonymously. If it
  # arrived as an Inertia visit, the signed-in pages are still in that document's history, so the
  # anonymous page that replaces them must clear it.
  test "detaching stale credentials clears Inertia history on the page that follows" do
    headers = as_user_headers(@user, host: @host)
    ClientToken.where(id: @token.id).delete_all

    get base_app_root_url(ri: "jp", host: @host), headers: headers

    assert_response :success
    assert inertia_page.fetch("clearHistory")
  end

  private

  def assert_no_store
    assert_includes response.headers["Cache-Control"].to_s.split(",").map(&:strip), "no-store",
                    "expected no-store, got #{response.headers["Cache-Control"].inspect}"
  end

  def same_host?(location)
    URI.parse(location).host.in?([nil, @host])
  end

  def bootstrap_and_select!(user, token)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    BaseSelectorAuthority.prepare(surface: :app, principal: user, session: token)
  end

  # DAMP local helper copy, as in the other Base controller tests.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil, **)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type || "client",
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value),
    )
  end

  def jwt_issuer_id_for_test_host(host)
    normalized = host.to_s
    service = (normalized.include?("auth") || normalized.include?("sign")) ? "SIGN" : "BASE"
    "surface:#{service}_APP"
  end
end
