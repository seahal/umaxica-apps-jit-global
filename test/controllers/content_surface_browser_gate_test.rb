# typed: false
# frozen_string_literal: true

require "test_helper"

# `allow_browser versions: :modern` used to sit on each content surface's BareController, which is
# also the parent of the /api/v0/entries, health probe, revision, and CSP report endpoints. A client
# reporting an old browser therefore received public/406-unsupported-browser.html from an API path.
# The gate now sits on the HTML controller that actually renders a page.
class ContentSurfaceBrowserGateTest < ActionDispatch::IntegrationTest
  HOST = ENV.fetch("PRIVATE_DOCS_SERVICE_URL", "docs.app.localhost")

  # Safari 16 is below the :modern floor (17.2), so this is a user agent the gate blocks.
  OUTDATED_BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " \
                     "(KHTML, like Gecko) Version/16.0 Safari/605.1.15"

  setup do
    host! HOST
    https!
  end

  test "the entries api answers an outdated browser with json, not an html gate page" do
    get "/api/v0/entries", headers: outdated_headers.merge("Accept" => "application/json")

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_not_includes response.body, "<html"
  end

  test "health probes answer an outdated user agent rather than gating them" do
    %w(/health/liveness /health/readiness /health/startup).each do |path|
      get path, headers: outdated_headers.merge("Accept" => "application/json")

      assert_not_equal 406, response.status, "#{path} refused a probe on browser version grounds"
      assert_equal "text/plain", response.media_type
      assert_not_includes response.body, "<html"
    end
  end

  test "the machine health json endpoint is not gated on browser version" do
    get "/api/v0/health.json", headers: outdated_headers.merge("Accept" => "application/json")

    assert_not_equal 406, response.status
    assert_equal "application/json", response.media_type
    assert_not_includes response.body, "<html"
  end

  test "the revision endpoint is not gated on browser version" do
    get "/revision", headers: outdated_headers

    assert_not_equal 406, response.status
  end

  test "the html landing page still gates outdated browsers" do
    get "/", headers: outdated_headers.merge("Accept" => "text/html")

    assert_response :not_acceptable
  end

  test "the html landing page still serves a modern browser" do
    get "/", headers: { "Accept" => "text/html", "User-Agent" => modern_browser }

    assert_response :success
  end

  private

  def outdated_headers
    { "User-Agent" => OUTDATED_BROWSER }
  end

  def modern_browser
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) " \
      "Chrome/131.0.0.0 Safari/537.36"
  end
end
