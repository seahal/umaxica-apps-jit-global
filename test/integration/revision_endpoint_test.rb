# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Contract for the deployment identifier endpoints. Every FQDN this application answers must expose
#
#   GET/HEAD /revision          -> text/plain, body exactly "<revision>\n"  (nil -> "\n")
#   GET      /api/v0/revision.json -> application/json, {"revision":"<sha>"} (nil -> {"revision":null})
#
# and the value must come only from Rails.application.revision, shared by both representations.
class RevisionEndpointTest < ActionDispatch::IntegrationTest
  REVISION = "0123456789abcdef0123456789abcdef01234567"

  JSON_BRACE = /\A\s*[{\[]/
  HTML_MARKER = /<!doctype|<html/i

  SURFACES = [
    { host: ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"), realm: "auth", surface: "app" },
    { host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"), realm: "auth", surface: "com" },
    { host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"), realm: "auth", surface: "org" },
    { host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"), realm: "base", surface: "app" },
    { host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"), realm: "base", surface: "com" },
    { host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"), realm: "base", surface: "org" },
    { host: ENV.fetch("PRIVATE_BASE_NETWORK_URL", "base.net.localhost"), realm: "base", surface: "net" },
    { host: ENV.fetch("PRIVATE_BASE_DEVELOPER_URL", "base.dev.localhost"), realm: "base", surface: "dev" },
    { host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"), realm: "core", surface: "app" },
    { host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"), realm: "core", surface: "com" },
    { host: ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost"), realm: "core", surface: "org" },
    { host: ENV.fetch("PRIVATE_CORE_NETWORK_URL", "core.net.localhost"), realm: "core", surface: "net" },
    { host: ENV.fetch("PRIVATE_CORE_DEVELOPER_URL", "core.dev.localhost"), realm: "core", surface: "dev" },
    { host: ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost"), realm: "side", surface: "app" },
    { host: ENV.fetch("PUBLIC_SIDE_CORPORATE_URL", "side.com.localhost"), realm: "side", surface: "com" },
    { host: ENV.fetch("PUBLIC_SIDE_STAFF_URL", "side.org.localhost"), realm: "side", surface: "org" },
    { host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"), realm: "palm", surface: "app" },
    { host: ENV.fetch("PRIVATE_HELP_SERVICE_URL"), realm: "help", surface: "app" },
    { host: ENV.fetch("PRIVATE_HELP_CORPORATE_URL"), realm: "help", surface: "com" },
    { host: ENV.fetch("PRIVATE_HELP_STAFF_URL"), realm: "help", surface: "org" },
    { host: ENV.fetch("PRIVATE_DOCS_SERVICE_URL"), realm: "docs", surface: "app" },
    { host: ENV.fetch("PRIVATE_DOCS_CORPORATE_URL"), realm: "docs", surface: "com" },
    { host: ENV.fetch("PRIVATE_DOCS_STAFF_URL"), realm: "docs", surface: "org" },
    { host: ENV.fetch("PRIVATE_NEWS_SERVICE_URL"), realm: "news", surface: "app" },
    { host: ENV.fetch("PRIVATE_NEWS_CORPORATE_URL"), realm: "news", surface: "com" },
    { host: ENV.fetch("PRIVATE_NEWS_STAFF_URL"), realm: "news", surface: "org" },
    { host: "info.app.localhost", realm: "info", surface: "app" },
    { host: "info.com.localhost", realm: "info", surface: "com" },
    { host: "info.org.localhost", realm: "info", surface: "org" },
  ].freeze

  SURFACES.each do |surface|
    test "#{surface[:realm]}/#{surface[:surface]} routes both revision endpoints to its own controllers" do
      text_controller = "#{surface[:realm]}/#{surface[:surface]}/revisions"
      json_controller = "#{surface[:realm]}/#{surface[:surface]}/api/v0/revisions"

      %i(get head).each do |method|
        recognized = Rails.application.routes.recognize_path(
          "http://#{surface[:host]}/revision", method: method,
        )

        assert_equal text_controller, recognized[:controller]
        assert_equal "show", recognized[:action]
      end

      recognized_json = Rails.application.routes.recognize_path(
        "http://#{surface[:host]}/api/v0/revision.json", method: :get,
      )

      assert_equal json_controller, recognized_json[:controller]
      assert_equal "show", recognized_json[:action]
    end
  end

  test "every revisions controller is bare and uses the shared rendering concern" do
    SURFACES.each do |surface|
      %W(#{surface[:realm]}/#{surface[:surface]}/revisions
         #{surface[:realm]}/#{surface[:surface]}/api/v0/revisions).each do |controller|
        controller_class = "#{controller}_controller".camelize.constantize

        assert_includes controller_class.ancestors, ::ApplicationRevisionRendering
        assert_equal :bare, controller_class.const_get(:AUTHENTICATION_MODE, false)
      end
    end
  end

  test "every surface host answers the text revision contract with the same value" do
    bodies = []

    SURFACES.each do |surface|
      host! surface[:host]

      Rails.application.stub(:revision, REVISION) do
        get "/revision"
      end

      assert_response :success, "GET /revision failed on #{surface[:host]}"
      assert_not_predicate response, :redirect?
      assert_equal "text/plain", response.media_type
      assert_not_equal "application/json", response.media_type
      assert_not_equal "text/html", response.media_type
      assert_equal "#{REVISION}\n", response.body
      assert_no_match JSON_BRACE, response.body
      assert_no_match HTML_MARKER, response.body
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]

      bodies << response.body
    end

    assert_equal ["#{REVISION}\n"], bodies.uniq,
                 "surfaces disagreed on the revision value"
  end

  test "every surface host answers the JSON revision contract" do
    SURFACES.each do |surface|
      host! surface[:host]

      Rails.application.stub(:revision, REVISION) do
        get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
      end

      assert_response :success, "GET /api/v0/revision.json failed on #{surface[:host]}"
      assert_not_predicate response, :redirect?
      assert_equal "application/json", response.media_type
      assert_not_equal "text/plain", response.media_type
      assert_not_equal "text/html", response.media_type
      assert_no_match HTML_MARKER, response.body
      assert_equal({ "revision" => REVISION }, response.parsed_body)
      assert_equal %w(revision), response.parsed_body.keys
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "the JSON revision endpoint refuses a non-JSON Accept with 406, no text or HTML fallback" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    ["text/html", "text/plain"].each do |accept|
      Rails.application.stub(:revision, REVISION) do
        get "/api/v0/revision.json", headers: { "Accept" => accept }
      end

      assert_response :not_acceptable, "Accept: #{accept}"
      assert_empty response.body
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "a missing revision is a normal response in both representations" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    Rails.application.stub(:revision, nil) do
      get "/revision"
    end

    assert_response :success
    assert_equal "\n", response.body
    assert_equal "text/plain", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]

    Rails.application.stub(:revision, nil) do
      get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
    end

    assert_response :success
    assert_equal({ "revision" => nil }, response.parsed_body)
  end

  test "revision is passed through verbatim without truncation in both representations" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")
    verbatim = "v2026.08.11+#{REVISION}"

    Rails.application.stub(:revision, verbatim) do
      get "/revision"
    end

    assert_equal "#{verbatim}\n", response.body

    Rails.application.stub(:revision, verbatim) do
      get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
    end

    assert_equal({ "revision" => verbatim }, response.parsed_body)
  end

  test "text revision never renders html or an authentication redirect under any Accept" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    [nil, "text/html", "*/*", "application/json"].each do |accept|
      headers = accept ? { "Accept" => accept } : {}

      Rails.application.stub(:revision, REVISION) do
        get "/revision", headers: headers
      end

      assert_response :success
      assert_equal "text/plain", response.media_type
      assert_not_predicate response, :redirect?
      assert_no_match HTML_MARKER, response.body
      assert_equal "#{REVISION}\n", response.body
    end
  end

  test "neither revision endpoint issues a database query" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    assert_no_queries do
      Rails.application.stub(:revision, REVISION) do
        get "/revision"
      end
    end
    assert_response :success

    assert_no_queries do
      Rails.application.stub(:revision, REVISION) do
        get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
      end
    end
    assert_response :success
  end

  test "revision responses leak no internal detail" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    forbidden = [
      Rails.root.to_s,
      Rails.application.class.name,
      ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost"),
      "secret_key_base",
      "REVISION",
      "git",
    ]

    Rails.application.stub(:revision, REVISION) do
      get "/revision"
    end

    forbidden.each { |value| assert_not_includes response.body, value }
    assert_no_match(%r{\.rb:\d+|backtrace|Traceback}, response.body)

    Rails.application.stub(:revision, REVISION) do
      get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
    end

    forbidden.each { |value| assert_not_includes response.body, value }
    assert_equal(%w(revision), response.parsed_body.keys)
  end

  test "HEAD /revision satisfies the text contract with an empty body" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    Rails.application.stub(:revision, REVISION) do
      get "/revision"
    end
    get_content_type = response.headers["Content-Type"]

    Rails.application.stub(:revision, REVISION) do
      head "/revision"
    end

    assert_response :success
    assert_equal get_content_type, response.headers["Content-Type"]
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_empty response.body
  end

  test "unknown hosts gain no revision route" do
    ["revision.example.test", "wrong.example.test"].each do |host|
      assert_raises(ActionController::RoutingError, "#{host} must not be routable") do
        Rails.application.routes.recognize_path("http://#{host}/revision", method: :get)
      end

      assert_raises(ActionController::RoutingError, "#{host} must not be routable") do
        Rails.application.routes.recognize_path("http://#{host}/api/v0/revision.json", method: :get)
      end
    end
  end
end
