# typed: false
# frozen_string_literal: true

require "test_helper"

class SignComLayoutTest < ActionDispatch::IntegrationTest
  test "auth footer does not link www identity" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")

    get new_auth_com_sign_up_email_url(ri: "jp"), headers: { "Host" => host }

    assert_response :success

    footer_hrefs = Array(inertia_props.fetch("chrome").fetch("footer_navigation")).map { |link| link.fetch("href") }

    assert_empty footer_hrefs.grep(%r{/identity\b}), "auth footer must not link www identity"
    assert_empty(
      footer_hrefs.select { |href| URI.parse(href).path == "/" },
      "auth footer must not link the ceremony-service home",
    )
  end
end
