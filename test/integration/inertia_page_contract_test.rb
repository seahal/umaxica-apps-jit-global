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

  # Inertia.js 3 reads the initial page from a JSON <script> element keyed by the root element id.
  # The older form, a `data-page` attribute on the root element, is not read by the client at all.
  # The root element id is the inertia_rails default, and `createInertiaApp` is booted without an
  # `id` override (spec/entrypoints/inertia.test.ts), so both sides meet on the upstream default.
  test "initial response carries the page in a script element and leaves the root element bare" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

    assert_response :success
    assert_select "script[data-page='app'][type='application/json']", count: 1
    assert_select "div#app", count: 1
    assert_select "div[data-page]", count: 0
  end

  test "initial page script carries the response CSP nonce" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

    assert_response :success

    nonce = css_select("meta[property='csp-nonce']").first["nonce"]

    assert_predicate nonce, :present?
    assert_equal nonce, css_select("script[data-page='app']").first["nonce"]
  end

  test "a page with no validation failure still carries an empty errors hash" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

    assert_response :success
    assert_empty(initial_page.fetch("props").fetch("errors"))

    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: authenticated_inertia_headers(version: ViteRuby.digest),
    )

    assert_response :success
    assert_empty(response.parsed_body.fetch("props").fetch("errors"))
  end

  test "history is encrypted and not cleared on an ordinary page, initial and Inertia alike" do
    get(base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host))

    assert_response :success
    assert initial_page.fetch("encryptHistory")
    assert_not initial_page.fetch("clearHistory")

    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: authenticated_inertia_headers(version: ViteRuby.digest),
    )

    assert_response :success
    assert response.parsed_body.fetch("encryptHistory")
    assert_not response.parsed_body.fetch("clearHistory")
  end

  # The page url is origin-relative by protocol: it never names a host, so one tenant's host cannot
  # reach another tenant's page object through it. Partitions: several parameters, and a
  # percent-encoded non-ASCII value, which must come back byte for byte rather than re-encoded.
  test "page url keeps several query parameters and stays origin-relative" do
    get(
      base_app_groups_url(ri: "jp", page: "2", host: @host),
      headers: authenticated_inertia_headers(version: ViteRuby.digest),
    )

    assert_response :success
    assert_equal "/groups?page=2&ri=jp", response.parsed_body.fetch("url")
  end

  test "page url keeps a percent-encoded non-ASCII query value unchanged" do
    get(
      "https://#{@host}/groups?ri=jp&q=%E6%9D%B1%E4%BA%AC%20a%2Bb",
      headers: authenticated_inertia_headers(version: ViteRuby.digest),
    )

    assert_response :success
    assert_equal "/groups?ri=jp&q=%E6%9D%B1%E4%BA%AC%20a%2Bb", response.parsed_body.fetch("url")
  end

  # The version is derived from the Vite sources once per process, so a request for another
  # tenant's host cannot make it differ.
  test "asset version is identical for an Inertia page served on another surface host" do
    get(
      base_app_groups_url(ri: "jp", host: @host),
      headers: authenticated_inertia_headers(version: ViteRuby.digest),
    )

    assert_response :success

    app_version = response.parsed_body.fetch("version")
    com_host = configured_host(:base_corporate)

    get(
      base_com_preference_url(ri: "jp", host: com_host),
      headers: { "Host" => com_host, "X-Inertia" => "true", "X-Inertia-Version" => app_version },
    )

    assert_response :success
    assert_equal app_version, response.parsed_body.fetch("version")
  end

  # The stale-version refresh names the request's own origin. Sent to the com host, it must come
  # back for the com host and never for the app host this test class otherwise uses.
  test "a stale version refresh on another surface host names that host and keeps the query" do
    com_host = configured_host(:base_corporate)

    get(
      base_com_preference_url(ri: "jp", host: com_host),
      headers: { "Host" => com_host, "X-Inertia" => "true", "X-Inertia-Version" => "stale-asset-version" },
    )

    assert_response :conflict

    location = URI.parse(response.headers["X-Inertia-Location"])

    assert_equal com_host, location.host
    assert_equal "/preference", location.path
    assert_equal "ri=jp", location.query
    assert_not_equal @host, location.host
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
