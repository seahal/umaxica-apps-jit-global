# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOrgLayoutTest < ActionDispatch::IntegrationTest
  test "auth footer does not link www identity" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")

    get auth_org_root_url(ri: "jp"), headers: { "Host" => host }

    assert_response :success

    footer_hrefs = Array(inertia_props.fetch("chrome").fetch("footer_navigation")).map { |link| link.fetch("href") }

    assert_empty footer_hrefs.grep(%r{/identity\b}), "auth footer must not link www identity"
    assert_empty(
      footer_hrefs.select { |href| URI.parse(href).path == "/" },
      "auth footer must not link the ceremony-service home",
    )
  end
end
