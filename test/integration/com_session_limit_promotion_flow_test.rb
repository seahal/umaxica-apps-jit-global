# typed: false
# frozen_string_literal: true

require "test_helper"

class ComSessionLimitPromotionFlowTest < ActionDispatch::IntegrationTest
  include AuthCeremonyEntryHelper

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    @base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "www.umaxica.com")
    host! @host
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "a visitor at the session limit revokes the existing session and continues sign-in" do
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorToken.where(visitor_id: visitor.id).delete_all
    address = "com-limit-#{SecureRandom.hex(4)}@example.com"
    email = VisitorEmail.create!(
      visitor_id: visitor.id, address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    existing = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB, skip_session_limit_check: true,
    )
    ensure_local_sign_in_admission!(
      surface: "com", path: auth_com_sign_in_path, params: { ri: "jp" }, headers: { "Host" => @host },
    )
    post auth_com_sign_in_email_url(ri: "jp"),
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t" }
    key = ROTP::Base32.random_base32
    email.store_otp(key, 7, 12.minutes.from_now.to_i)
    patch auth_com_sign_in_email_url(ri: "jp"),
          params: { "visitor_email" => { "pass_code" => ROTP::HOTP.new(key).at(7).to_s }, "cf-turnstile-response" => "t" }
    follow_redirect! if response.redirect?
    follow_redirect! if response.redirect?
    post auth_com_sign_handoff_path(ri: "jp"), params: { ri: "jp" }
    result_form = response.parsed_body.at_css("form")
    result = result_form.at_css('input[name="result"]')["value"]
    transaction_ref = result_form.at_css('input[name="transaction_ref"]')["value"]
    host! @base_host
    post base_com_sign_completion_path,
         params: { result: result, transaction_ref: transaction_ref, ri: "jp" },
         headers: { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-site" }
    follow_redirect! if response.redirect?

    assert_response :success
    assert_equal "base/com/sign/in/limitations/show", inertia_component
    items = inertia_props.fetch("sessions")

    assert_equal 1, items.size

    patch base_com_sign_in_limitation_path(ri: "jp"), params: { session_ref: items.first.fetch("session_ref") }

    assert_response :redirect
    assert_predicate existing.reload, :revoked?
    cycle = VisitorSignInFlow.where(principal_id: visitor.id).recent_first.first
    resolution = VisitorSessionLimitResolutionTransaction.find_by!(sign_in_flow_id: cycle.id)

    assert_predicate cycle, :sign_in_completed?
    assert_predicate cycle.token_id, :present?
    assert_predicate resolution, :resolved?
  end
end
