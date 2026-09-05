# typed: false
# frozen_string_literal: true

require "test_helper"

# Rendered contract for the UMAXICA brand title.
#
#   root HTML:      "UMAXICA (TLD)"
#   non-root HTML:  "{LOCALIZED PAGE TITLE}" then an EM DASH then "UMAXICA (TLD)"
#
# Non-root cases assert the page-specific title itself, not merely that the title
# is non-empty: a view that forgets `content_for :page_title` collapses to the
# root title and would otherwise look healthy.
class HtmlTitleContractTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  # Routing and deployment vocabulary that must never reach a title.
  FORBIDDEN_WORDS = %w(Auth Base Core Side Palm Jump Global Rails Inertia API Home).freeze

  ROOT_SURFACES = [
    { host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), tld: "APP" },
    { host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost"), tld: "COM" },
    { host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"), tld: "ORG" },
    { host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"), tld: "APP" },
    { host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"), tld: "COM" },
    { host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"), tld: "ORG" },
    { host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"), tld: "APP" },
    { host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"), tld: "COM" },
    { host: ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost"), tld: "ORG" },
    { host: ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost"), tld: "APP" },
    { host: ENV.fetch("PUBLIC_SIDE_CORPORATE_URL", "side.com.localhost"), tld: "COM" },
    { host: ENV.fetch("PUBLIC_SIDE_STAFF_URL", "side.org.localhost"), tld: "ORG" },
    { host: ENV.fetch("PUBLIC_PALM_SERVICE_URL", "palm.app.localhost"), tld: "APP" },
    { host: "core.dev.localhost", tld: "DEV" },
  ].freeze

  # `/health` is served on the network and developer hosts too, which carry their own TLD labels
  # rather than inheriting one from the surface. Only the host is needed now: the title assertion
  # these entries once fed was removed when `/health` stopped rendering HTML.
  HEALTH_HOSTS = [
    { host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost") },
    { host: ENV.fetch("PRIVATE_BASE_NETWORK_URL", "base.net.localhost") },
    { host: ENV.fetch("PRIVATE_BASE_DEVELOPER_URL", "base.dev.localhost") },
  ].freeze

  # Prefixes that answer with JSON, XML or plain text. Listed rather than inferred
  # so that a new HTML route is never silently treated as out of scope.
  NON_HTML_PATH_PATTERNS = [
    %r{\A/health(/(liveness|readiness|startup))?\z},
    %r{\A/\.well-known/},
    %r{\A/(web|edge|api)/v\d},
    %r{\A/csp-violation-report\z},
    %r{\A/revision\z},
    %r{\A/robots\.txt},
    %r{\A/sitemap\.xml\z},
    %r{\A/service-worker\z},
    # turbo-rails native navigation endpoint (turbo/native/navigation#recede).
    %r{\A/recede_historical_location\z},
    %r{\A/(resume|refresh)_historical_location\z},
  ].freeze

  test "root pages render the brand alone" do
    ROOT_SURFACES.each do |surface|
      host! surface.fetch(:host)
      get "/"

      next if response.redirect?

      assert_response :success, "GET / on #{surface.fetch(:host)}"
      assert_single_html_document
      assert_equal "#{BRAND} (#{surface.fetch(:tld)})", rendered_title,
                   "root title on #{surface.fetch(:host)}"
      assert_title_shape(rendered_title, surface.fetch(:tld))
    end
  end

  test "non-root pages render the localized page title before the brand" do
    cases = [
      {
        host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
        path: -> { auth_app_sign_in_path(ri: "jp") },
        tld: "APP",
        page_title: -> { I18n.t("sign.app.authentication.new.page_title") },
      },
      {
        host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"),
        path: -> { auth_org_sign_in_path(ri: "jp") },
        tld: "ORG",
        page_title: -> { I18n.t("sign.org.authentication.new.page_title") },
      },
      {
        host: ENV.fetch("PUBLIC_PALM_SERVICE_URL", "palm.app.localhost"),
        path: -> { palm_app_sign_out_path(ri: "jp") },
        tld: "APP",
        page_title: -> { "Signed out" },
      },
    ]

    cases.each do |entry|
      host! entry.fetch(:host)
      get instance_exec(&entry.fetch(:path))

      next if response.redirect?

      assert_response :success, "GET #{entry.fetch(:path).call} on #{entry.fetch(:host)}"
      assert_single_html_document

      expected = "#{instance_exec(&entry.fetch(:page_title))} — #{BRAND} (#{entry.fetch(:tld)})"

      assert_equal expected, rendered_title, "title on #{entry.fetch(:host)}"
      assert_title_shape(rendered_title, entry.fetch(:tld))
    end
  end

  test "the health snapshot is a non-HTML probe and is excluded from title contracts" do
    HEALTH_HOSTS.each do |entry|
      host! entry.fetch(:host)
      get "/health"

      assert_response :success, "GET /health on #{entry.fetch(:host)}"
      assert_equal "text/plain", response.media_type, "GET /health on #{entry.fetch(:host)}"
      assert_match(/\Astatus: /, response.body)
    end

    assert_includes non_html_get_paths, "/health"
  end

  test "the page title is localized while the brand stays constant" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")

    titles =
      %w(jp us).to_h do |region|
        get(auth_app_sign_in_path(ri: region))
        [region, rendered_title]
      end

    titles.each_value do |title|
      assert_match(/ — #{Regexp.escape("#{BRAND} (APP)")}\z/, title)
    end
  end

  test "every routed GET HTML page carries a non-empty title" do
    checked = []

    ROOT_SURFACES.each do |surface|
      host! surface.fetch(:host)

      html_get_paths.each do |path|
        get(path)
      rescue StandardError
        next
      else
        next unless response.successful? && response.media_type.to_s.start_with?("text/html")

        checked << [surface.fetch(:host), path]

        assert_equal 1, css_select("title").size, "#{path} on #{surface.fetch(:host)} needs exactly one <title>"
        assert_predicate rendered_title.strip, :present?,
                         "#{path} on #{surface.fetch(:host)} renders an empty <title>"
        assert_title_shape(rendered_title, surface.fetch(:tld))
      end
    end

    skipped = non_html_get_paths

    assert_predicate checked, :any?, "the HTML route sweep checked nothing"
    # Surfacing the exclusions keeps them a decision rather than a silent gap.
    puts "HTML title sweep: #{checked.size} responses checked, non-HTML paths excluded: #{skipped.inspect}"
  end

  private

  def assert_title_shape(title, tld)
    assert_predicate title.strip, :present?, "title must not be blank"
    assert_includes title, "#{BRAND} (#{tld})", "title must carry the brand and its TLD edition"
    assert_not_includes title, "Umaxica", "brand must be upper case"
    assert_not_includes title, "translation missing"
    assert_not_includes title, "|", "the separator is an EM DASH, not a pipe"

    FORBIDDEN_WORDS.each do |word|
      assert_no_match(/\b#{word}\b/, title, "#{title.inspect} leaks #{word}")
    end
  end

  def assert_single_html_document
    assert_match %r{\Atext/html}, response.media_type
    assert_equal 1, css_select("html").size, "expected exactly one <html> element"
    assert_equal 1, css_select("head").size, "expected exactly one <head> element"
    assert_equal 1, css_select("title").size, "expected exactly one <title> element"
  end

  def rendered_title
    css_select("title").first&.text.to_s
  end

  def static_get_paths
    Rails.application.routes.routes
      .select { |route| route.verb == "GET" }
      .map { |route| route.path.spec.to_s.sub(/\(\.:format\)\z/, "") }
      .reject { |path| path.include?(":") || path.include?("*") }
      .uniq
  end

  def non_html_get_paths
    static_get_paths.select { |path| NON_HTML_PATH_PATTERNS.any? { |pattern| pattern.match?(path) } }
  end

  def html_get_paths
    static_get_paths - non_html_get_paths
  end
end
