# typed: false
# frozen_string_literal: true

require "test_helper"

# Contract for the Rails-side Inertia protocol on the only Inertia endpoint in the application
# (Base::App::GroupsController#index).
#
# The pre-existing controller test asserted HTML substrings only, so it could not observe the page
# object Inertia actually navigates on: component, props, url, version. Every assertion here reads
# the protocol payload rather than the markup around it.
class InertiaPageContractTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_service)
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end

  test "initial response embeds the full page object, not just a component name" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

    assert_response :success

    page = initial_page

    assert_equal "base/app/groups/index", page.fetch("component")
    assert_equal "Groups", page.dig("props", "title")
    assert_kind_of Array, page.dig("props", "groups")
    assert_equal ViteRuby.digest, page.fetch("version")
    assert page.fetch("encryptHistory"), "encrypt_history is configured on, so the page must carry it"
  end

  # The `url` key is the client's notion of the current page. Inertia resolves every subsequent
  # visit and every history entry against it, so a wrong value desynchronises the SPA from the
  # address bar.
  test "initial page url is the requested path including the query string" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

    assert_response :success
    assert_equal "/groups?ri=jp", initial_page.fetch("url")
  end

  test "an Inertia visit returns the page object as JSON with the same current page url" do
    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: authenticated_inertia_headers(version: ViteRuby.digest),
    )

    assert_response :success
    assert_equal "true", response.headers["X-Inertia"]
    assert_equal "application/json", response.media_type

    page = response.parsed_body

    assert_equal "base/app/groups/index", page.fetch("component")
    assert_equal "/groups?ri=jp", page.fetch("url")
    assert_equal ViteRuby.digest, page.fetch("version")
  end

  test "an Inertia visit carrying a stale asset version is answered with a hard location refresh" do
    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: authenticated_inertia_headers(version: "stale-asset-version"),
    )

    assert_response :conflict
    assert_equal(
      base_app_groups_url(ri: "jp", host: @host),
      response.headers["X-Inertia-Location"],
    )
  end

  # An Inertia visit is a `fetch` call. A 302 is followed transparently by the browser, so the
  # client receives the sign-in HTML page as the body of what it believes is an Inertia response,
  # throws "All Inertia requests must receive a valid Inertia response", and leaves the SPA on the
  # stale current page. The protocol's answer for leaving the Inertia application is a 409 with
  # X-Inertia-Location, which the client turns into a full document visit.
  test "an unauthenticated Inertia visit leaves the app with a location refresh, not a redirect" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: inertia_headers(version: ViteRuby.digest))

    assert_response :conflict

    location = response.headers["X-Inertia-Location"]

    assert_predicate location, :present?

    assert_base_sign_entry_redirect(location, surface: :app)
  end

  test "a plain unauthenticated browser request still redirects" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: host_headers(@host))

    assert_response :redirect
  end

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def inertia_headers(version: nil)
    headers = host_headers(@host).merge(
      "X-Inertia" => "true",
      "Accept" => "text/html, application/xhtml+xml",
    )
    headers["X-Inertia-Version"] = version if version
    headers
  end

  def authenticated_inertia_headers(version: nil)
    as_user_headers(@user, host: @host).merge(inertia_headers(version: version))
  end

  def initial_page
    element = css_select("script[data-page='app']").first

    assert element, "the initial response must embed the Inertia page object"

    JSON.parse(element.text)
  end
end
