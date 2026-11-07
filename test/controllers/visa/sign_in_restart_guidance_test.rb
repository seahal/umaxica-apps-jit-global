# typed: false
# frozen_string_literal: true

require "test_helper"

class VisaSignInRestartGuidanceTest < ActionDispatch::IntegrationTest
  test "APP invalid resolution points to Base APP sign and refused GET is read only" do
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! visa_host
    https!
    cookies_before = cookies.to_hash.deep_dup
    resolutions_before = ClientSessionLimitResolutionTransaction.order(:id).map(&:attributes)
    restart_url = base_app_sign_show_url(host: base_host, protocol: "https", ri: "jp")

    get visa_app_sign_in_limitation_path(ri: "jp", return_to: "https://attacker.invalid"),
        headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }

    assert_response :gone
    assert_includes response.body, restart_url
    assert_not_includes response.body, "attacker.invalid"
    assert_equal cookies_before, cookies.to_hash
    assert_equal resolutions_before, ClientSessionLimitResolutionTransaction.order(:id).map(&:attributes)

    host! base_host
    get base_app_sign_show_path(ri: "jp"),
        headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }

    assert_response :success
  end

  test "ORG invalid resolution points to Base ORG sign and refused GET is read only" do
    visa_host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! visa_host
    https!
    cookies_before = cookies.to_hash.deep_dup
    resolutions_before = OperatorSessionLimitResolutionTransaction.order(:id).map(&:attributes)
    restart_url = base_org_sign_show_url(host: base_host, protocol: "https", ri: "jp")

    get visa_org_sign_in_limitation_path(ri: "jp", return_to: "https://attacker.invalid"),
        headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }

    assert_response :gone
    assert_includes response.body, restart_url
    assert_not_includes response.body, "attacker.invalid"
    assert_equal cookies_before, cookies.to_hash
    assert_equal resolutions_before, OperatorSessionLimitResolutionTransaction.order(:id).map(&:attributes)

    host! base_host
    get base_org_sign_show_path(ri: "jp"),
        headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }

    assert_response :success
  end
end
