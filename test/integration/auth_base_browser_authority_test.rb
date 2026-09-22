# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthBaseBrowserAuthorityTest < ActionDispatch::IntegrationTest
  test "anonymous Base protected access enters Auth through a local admission" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    issued_url = nil

    host! base_host

    JumpRtIssuer.stub(:call, ->(**args) { issued_url = args.fetch(:url); "signed-jump-token" }) do
      RedirectsJumpGatewayUrl.stub(
        :call,
        ->(_token) { RedirectsTargetResult.ok(kind: :external, source: :test, value: issued_url) },
      ) do
        get base_app_accounts_url(ri: "jp")
      end
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal auth_host, uri.host
    assert_equal auth_app_sign_in_path, uri.path
    assert_predicate query["entry_ref"], :present?
    assert_nil query["client_id"]
  end
end
