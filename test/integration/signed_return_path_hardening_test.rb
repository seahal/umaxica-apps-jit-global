# typed: false
# frozen_string_literal: true

require "test_helper"

# A caller-supplied return path is only ever carried forward as a signed, internal path. Starting
# the com email sign-up with a `pt` turns a safe path into a signed token on the OTP step; every
# form that could be reinterpreted as another origin or path (protocol-relative, encoded slashes or
# backslashes, control characters, embedded credentials, fragments, relative paths) is dropped.
class SignedReturnPathHardeningTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      VisitorEmailStatus::DEFAULTS.each { |id| VisitorEmailStatus.find_or_create_by!(id: id) }
    end
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

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "a safe internal return path is carried to the OTP step as a signed token" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host
    cookies["csrf_token"] = "test-csrf-token"

    post auth_com_sign_up_email_url(ri: "jp", host: host, pt: "/settings/emails?tab=1"),
         params: {
           visitor_email: { raw_address: "signed-pt-safe-#{SecureRandom.hex(4)}@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => host, "X-CSRF-Token" => "test-csrf-token" }

    assert_response :redirect
    carried = Rack::Utils.parse_query(URI.parse(response.location).query)["pt"]

    assert_predicate carried, :present?
    assert_not_equal "/settings/emails?tab=1", carried, "the path must be carried signed, not verbatim"
  end

  test "return paths that could escape the origin or path are dropped" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host
    cookies["csrf_token"] = "test-csrf-token"
    hostile = [
      "//evil.example.test/steal",
      "https://evil.example.test/steal",
      "https://user:pass@#{host}/settings",
      "/settings%2f..%2fadmin",
      "/settings%5c..%5cadmin",
      "/settings\\..\\admin",
      "/settings%0d%0aSet-Cookie:x=1",
      "/settings#fragment",
      "settings/relative",
    ]

    hostile.each do |value|
      post auth_com_sign_up_email_url(ri: "jp", host: host),
           params: {
             pt: value,
             visitor_email: { raw_address: "signed-pt-#{SecureRandom.hex(4)}@example.com", confirm_policy: "1" },
             "cf-turnstile-response": "test",
           },
           headers: { "Host" => host, "X-CSRF-Token" => "test-csrf-token" }

      assert_response :redirect, value
      location = URI.parse(response.location)

      assert_equal host, location.host || host, value
      assert_nil Rack::Utils.parse_query(location.query)["pt"], "#{value.inspect} was carried forward"
    end
  end
end
