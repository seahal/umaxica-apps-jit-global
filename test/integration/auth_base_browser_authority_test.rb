# frozen_string_literal: true

require "test_helper"
require_relative "../support/oidc_auth_admission_test_helper"

class AuthBaseBrowserAuthorityTest < ActionDispatch::IntegrationTest
  include OidcAuthAdmissionTestHelper

  test "anonymous Base access reaches Auth through Visa without creating a Root Session" do
    previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    roots_before = ClientToken.count
    transactions_before = ClientOidcAuthorizationTransaction.count

    bootstrap_auth_sign_in_admission!(surface: "app", region: "jp", target_link_uri: "/accounts")

    assert_response :success
    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), request.host
    assert_equal auth_app_sign_in_path, request.path
    assert_nil request.query_parameters["entry_ref"]
    assert_nil request.query_parameters["client_id"]
    assert_equal roots_before, ClientToken.count
    assert_equal transactions_before + 1, ClientOidcAuthorizationTransaction.count
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
  end
end
