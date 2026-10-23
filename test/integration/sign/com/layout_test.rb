# typed: false
# frozen_string_literal: true

require "test_helper"

class SignComLayoutTest < ActionDispatch::IntegrationTest
  setup do
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = OidcTestEntry.issue!(
      surface: "com", intent: "sign_up", base_browser_nonce: nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    attached, raw_sid = VisitorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil, browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "com", entry_ref: issuance.reference, nonce: nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "com", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, admitted_sid = VisitorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: issuance.transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    cookies[JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"] = admitted_sid
  end

  test "auth footer does not link www identity" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")

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
