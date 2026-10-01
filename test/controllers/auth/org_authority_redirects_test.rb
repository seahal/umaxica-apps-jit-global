# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::OrgAuthorityRedirectsTest < ActionDispatch::IntegrationTest
  ROUTES = {
    auth_org_configuration_url: "/configuration",
    auth_org_accounts_url: "/accounts",
    auth_org_iam_index_url: "/iam",
    auth_org_system_index_url: "/system",
    auth_org_audit_index_url: "/audit",
    auth_org_support_index_url: "/support",
    auth_org_billing_index_url: "/billing",
  }.freeze

  test "sign org residual authority routes redirect to base org" do
    ROUTES.each do |helper, path|
      get public_send(helper, host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"), ri: "jp")

      assert_response :see_other
      gateway = URI.parse(response.location)
    assert_equal "jump.umaxica.net", gateway.host
    payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)
    location = URI.parse(payload.fetch("url"))

      assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL"), location.host
      assert_equal path, location.path
    end
  end

  test "sign ceremony entry routes remain on sign" do
    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost")}/sign/in",
      method: :get,
    )

    assert_equal "auth/org/sign/ins", route.fetch(:controller)
    assert_equal "show", route.fetch(:action)
  end
end
