# typed: false
# frozen_string_literal: true

require "test_helper"

# Two small per-surface endpoints that every surface repeats: the sign-out entry
# redirect and the OAuth token revocation endpoint's rejection of an
# unauthenticated client.
class BaseSignOutAndOauthRevocationTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  self.fixture_table_names = []

  test "app sign-out entry redirects to the confirmation page" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get new_base_app_sign_out_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :see_other
    assert_redirected_to edit_base_app_sign_out_path(ri: "jp")
  end

  test "com sign-out entry redirects to the confirmation page" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host

    get new_base_com_sign_out_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :see_other
    assert_redirected_to edit_base_com_sign_out_path(ri: "jp")
  end

  test "org sign-out entry redirects to the confirmation page" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host

    get new_base_org_sign_out_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :see_other
    assert_redirected_to edit_base_org_sign_out_path(ri: "jp")
  end

  test "app sign-out completion page renders for a browser that has signed out" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_sign_out_completion_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "com sign-out completion page renders for a browser that has signed out" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host

    get base_com_sign_out_completion_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
  end

  test "org sign-out completion page renders for a browser that has signed out" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host

    get base_org_sign_out_completion_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
  end

  test "app sign-out confirmation page renders for an anonymous browser" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get edit_base_app_sign_out_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
  end

  test "com sign-out confirmation page renders for an anonymous browser" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host

    get edit_base_com_sign_out_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
  end

  test "app token revocation rejects an unknown client without disclosing token state" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    post base_app_oauth_revocation_url(host: host),
         params: { token: "not-a-real-token", client_id: "unknown-client", client_secret: "wrong" }

    assert_response :unauthorized
    assert_predicate response.parsed_body.fetch("error"), :present?
  end

  test "com token revocation rejects an unknown client without disclosing token state" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host

    post base_com_oauth_revocation_url(host: host),
         params: { token: "not-a-real-token", client_id: "unknown-client", client_secret: "wrong" }

    assert_response :unauthorized
    assert_predicate response.parsed_body.fetch("error"), :present?
  end

  test "org token revocation rejects an unknown client without disclosing token state" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host

    post base_org_oauth_revocation_url(host: host),
         params: { token: "not-a-real-token", client_id: "unknown-client", client_secret: "wrong" }

    assert_response :unauthorized
    assert_predicate response.parsed_body.fetch("error"), :present?
  end

  test "com token revocation answers 429 once the per-IP allowance is spent" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host

    21.times do
      post base_com_oauth_revocation_url(host: host),
           params: { token: "not-a-real-token", client_id: "unknown-client", client_secret: "wrong" }
    end

    assert_response :too_many_requests
  end

  test "org token revocation answers 429 once the per-IP allowance is spent" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host

    21.times do
      post base_org_oauth_revocation_url(host: host),
           params: { token: "not-a-real-token", client_id: "unknown-client", client_secret: "wrong" }
    end

    assert_response :too_many_requests
  end
end
