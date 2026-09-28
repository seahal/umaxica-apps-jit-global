# typed: false
# frozen_string_literal: true

require "test_helper"

class ComSessionLimitPromotionFlowTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
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
    address = "com-limit-#{SecureRandom.hex(4)}@example.com"
    email = VisitorEmail.create!(
      visitor_id: visitor.id, address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    existing = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    post auth_com_sign_in_email_url(ri: "jp"),
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t" }
    key = ROTP::Base32.random_base32
    email.store_otp(key, 7, 12.minutes.from_now.to_i)
    patch auth_com_sign_in_email_url(ri: "jp"),
          params: { "visitor_email" => { "pass_code" => ROTP::HOTP.new(key).at(7).to_s }, "cf-turnstile-response" => "t" }

    assert_equal "/sign/in/session", URI.parse(response.location).path
    # The com surface first normalizes the missing region onto the session page.
    follow_redirect! while response.redirect?
    items = inertia_props.fetch("active_sessions").fetch("items")

    assert_equal 1, items.size

    patch auth_com_sign_in_session_url(ri: "jp"), params: { revoke_refs: [items.first.fetch("ref")] }

    assert_response :redirect
    assert_predicate existing.reload, :revoked?
    cycle = VisitorSignInFlow.where(principal_id: visitor.id).recent_first.first

    assert_not cycle.sign_in_session_limit_pending?
    assert_predicate cycle.token_id, :present?
  end
end
