# typed: false
# frozen_string_literal: true

require "test_helper"

# D-50 (1): browser pages on the Sign-in path refuse outdated browsers with 406; server-to-server
# endpoints (token endpoint, Back-Channel Logout receiver) are not gated on the browser version.
class SignInPathBrowserAllowlistTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  # Safari 16 is below the :modern floor (17.2).
  OUTDATED_BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " \
                     "(KHTML, like Gecko) Version/16.0 Safari/605.1.15"
  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)

  test "Auth sign-in pages answer an outdated browser with 406 on every surface" do
    [BOOT_HOSTS.auth_service.host, BOOT_HOSTS.auth_corporate.host, BOOT_HOSTS.auth_staff.host].each do |host|
      host! host
      https!

      get "/sign/in", params: { ri: "jp" }, headers: { "User-Agent" => OUTDATED_BROWSER }

      assert_equal 406, response.status, host
    end
  end

  test "the token endpoint is not gated on the browser version" do
    host! BOOT_HOSTS.base_service.host
    https!

    post "/oauth/token", params: { grant_type: "authorization_code" }, headers: { "User-Agent" => OUTDATED_BROWSER }

    assert_not_includes [404, 406], response.status
  end

  test "the Back-Channel Logout receiver is not gated on the browser version" do
    host! BOOT_HOSTS.core_service.host
    https!

    post "/oidc/closures", params: { logout_token: "x" }, headers: { "User-Agent" => OUTDATED_BROWSER }

    assert_not_includes [404, 406], response.status
  end
end
