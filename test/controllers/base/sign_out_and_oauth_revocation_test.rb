# typed: false
# frozen_string_literal: true

require "test_helper"

# Two small per-surface endpoints that every surface repeats: the sign-out entry
# redirect and the OAuth token revocation endpoint's rejection of an
# unauthenticated client.
class BaseSignOutAndOauthRevocationTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

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

  test "app sign-out mutation answers with no-store and redirects to the lobby" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    post base_app_sign_out_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :see_other
    assert_equal base_app_lobby_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_includes response.headers["Cache-Control"].to_s, "no-store"
  end

  test "the retired app sign-out completion route is not recognized" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/sign/out/complete", method: :get)
    end
  end

  test "the retired com sign-out completion route is not recognized" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/sign/out/complete", method: :get)
    end
  end

  test "the retired org sign-out completion route is not recognized" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/sign/out/complete", method: :get)
    end
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
