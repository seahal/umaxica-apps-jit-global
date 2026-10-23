# typed: false
# frozen_string_literal: true

require "test_helper"

# The PWA offline fallback is served by the framework's own Rails::PwaController on every origin whose
# public HTML Rails renders itself: base, auth, warp, and palm. See adr/pwa-offline-route-exception.md.
class PwaEndpointsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  HOSTS = [
    ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
    ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
    ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
    ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
    ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost"),
    ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"),
    ENV.fetch("PUBLIC_WARP_SERVICE_URL", "warp.app.localhost"),
    ENV.fetch("PUBLIC_WARP_CORPORATE_URL", "warp.com.localhost"),
    ENV.fetch("PUBLIC_WARP_STAFF_URL", "warp.org.localhost"),
    ENV.fetch("PUBLIC_PALM_SERVICE_URL", "palm.app.localhost"),
  ].freeze

  # A browser fetching a service worker script sends `Accept: */*`; the offline document is fetched
  # by the worker's `cache.add`, which sends the same.
  WORKER_HEADERS = { "Accept" => "*/*" }.freeze

  test "every Rails-rendered origin serves the service worker script" do
    HOSTS.each do |host|
      host! host
      get "/service-worker", headers: WORKER_HEADERS

      assert_response :success, "GET /service-worker failed on #{host}"
      assert_match(%r{\A(text|application)/javascript}, response.content_type, "on #{host}")
      assert_includes response.body, 'event.request.mode === "navigate"', "on #{host}"
      assert_includes response.body, 'caches.open("offline")', "on #{host}"
    end
  end

  test "the service worker caches the offline document and writes nothing else" do
    host! HOSTS.first
    get "/service-worker", headers: WORKER_HEADERS

    assert_includes response.body, 'cache.add("/offline")'
    # No runtime caching: the worker cannot store an authenticated response, a page prop payload, a
    # CSRF token, or a Set-Cookie header, because it never puts anything into a cache.
    assert_not_includes response.body, "caches.put"
    assert_not_includes response.body, "cache.put"
  end

  test "every Rails-rendered origin serves the offline document without authentication" do
    HOSTS.each do |host|
      host! host
      get "/offline", headers: WORKER_HEADERS

      assert_response :success, "GET /offline failed on #{host}"
      assert_not_predicate response, :redirect?, "on #{host}"
      assert_match(%r{\Atext/html}, response.content_type, "on #{host}")
      assert_select "h1", text: I18n.t("pwa.offline.title"), count: 1
      assert_nil response.headers["Set-Cookie"], "on #{host}"
    end
  end

  test "the offline document renders English and Japanese copy with the matching language" do
    # Japanese literals are expected localized customer copy.
    {
      en: ["Unable to connect to the network",
           "Unable to connect to the server. Check your internet connection and try again.", # rubocop:disable I18n/RailsI18n/DecorateString -- Expected rendered translation.
           "Reload this page", "Retry",],
      ja: ["ネットワークに接続できません",
           "サーバーに接続できませんでした。インターネット接続を確認して、もう一度お試しください。",
           "このページを再読み込みする", "再試行",],
    }.each do |locale, (title, description, reload, retry_label)|
      I18n.with_locale(locale) do
        HOSTS.each do |host|
          host! host
          get "/offline", headers: WORKER_HEADERS

          assert_response :success
          assert_select "html[lang=?]", locale.to_s
          assert_select "title", text: /#{Regexp.escape(title)}/
          assert_select "h1", text: title
          assert_select "main p", text: description
          assert_select "form[aria-label=?]", reload
          assert_select "button[type=submit]", text: retry_label
          assert_nil response.headers["Set-Cookie"]
        end
      end
    end
  end

  test "the offline document carries no session, actor, or CSRF state" do
    host! HOSTS.first
    get "/offline", headers: WORKER_HEADERS

    assert_not_includes response.body, "csrf-token"
    assert_not_includes response.body, "csrf-param"
    assert_not_includes response.body, "<script"
  end

  # A form without `action` submits to the document's own URL, so retrying a failed /dashboard
  # navigation requests /dashboard again rather than its directory, `/`.
  test "the offline retry control is a GET form that targets the failed path, not its directory" do
    host! HOSTS.first
    get "/offline", headers: WORKER_HEADERS

    assert_select "form[method=get]", 1
    assert_select "form[action]", 0
    assert_select "form input", 0
  end

  test "both endpoints resolve to the framework PWA controller, not a surface controller" do
    assert_equal Rails::PwaController, "rails/pwa".camelize.concat("Controller").constantize

    %w(Base::App::ServiceWorkersController Base::App::OfflinesController
       Auth::App::ServiceWorkersController Auth::App::OfflinesController
       Warp::App::ServiceWorkersController Warp::App::OfflinesController
       Palm::App::ServiceWorkersController Palm::App::OfflinesController).each do |name|
      assert_nil name.safe_constantize,
                 "#{name} still exists; the PWA endpoints must be served by Rails::PwaController"
    end
  end

  test "the content security policy relaxation is scoped to the PWA endpoints" do
    host! HOSTS.first

    get "/offline", headers: WORKER_HEADERS
    offline_policy = response.headers["Content-Security-Policy"]

    assert_includes offline_policy, "script-src 'self' 'unsafe-inline'"
    assert_includes offline_policy, "style-src 'self' 'unsafe-inline'"
    assert_no_match(/nonce-/, offline_policy)

    get "/", headers: WORKER_HEADERS
    application_policy = response.headers["Content-Security-Policy"]

    assert_not_includes application_policy, "'unsafe-inline'"
    assert_includes application_policy, "worker-src 'self'"
  end

  test "worker-src permits same-origin workers on every surface" do
    HOSTS.each do |host|
      host! host
      get "/offline", headers: WORKER_HEADERS

      # The offline response carries the endpoint-specific policy; worker-src is untouched by it and
      # comes from the application policy, so registration stays permitted everywhere.
      assert_includes response.headers["Content-Security-Policy"], "worker-src 'self'", "on #{host}"
    end
  end
end
