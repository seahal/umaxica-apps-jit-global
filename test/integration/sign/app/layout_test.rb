# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignAppLayoutTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  def default_headers
    { "Host" => ENV["PRIVATE_AUTH_SERVICE_URL"] || "id.app.localhost" }
  end

  def login_headers(user)
    default_headers.merge("X-TEST-CURRENT-USER" => user.id.to_s)
  end

  setup do
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = OidcTestEntry.issue!(
      surface: "app", intent: "sign_up", base_browser_nonce: nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil, browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.reference, nonce: nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, admitted_sid = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: issuance.transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    cookies[JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"] = admitted_sid
  end

  test "the shared auth header exposes no sign-in or sign-up navigation" do
    get new_auth_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    chrome = inertia_props.fetch("chrome")

    # Auth pages are themselves the sign-in / sign-up surface. A header link back to those flows
    # forces the shared template to detect login state just to choose between "Sign in" and "Sign
    # up", which this surface should not have to do. Links a specific ceremony genuinely needs
    # belong in that page's own body, not the shared chrome.
    assert_not chrome.key?("primary_navigation"), "the auth chrome must not carry primary navigation"

    footer_hrefs = Array(chrome["footer_navigation"]).map { |link| link.fetch("href") }

    assert_empty footer_hrefs.grep(%r{/sign/in\b}), "auth footer must not link the sign-in flow"
    assert_empty footer_hrefs.grep(%r{/sign/up\b}), "auth footer must not link the sign-up flow"
    # Identity settings live on the www/base host and require an authenticated session. Linking
    # them from the unauthenticated sign-in chrome sends people to a page they cannot use.
    assert_empty footer_hrefs.grep(%r{/identity\b}), "auth footer must not link www identity"
    # The auth root is itself the ceremony-service home. Linking it from the shared footer
    # sends people back to https://auth.umaxica.app/?ri=... with no additional destination.
    assert_empty(
      footer_hrefs.select { |href| URI.parse(href).path == "/" },
      "auth footer must not link the ceremony-service home",
    )
  end

  test "cookie banner settings url is the base cookie preference edit" do
    get new_auth_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    settings_url = inertia_props.dig("chrome", "cookie_controls", "settings_url")
    uri = URI.parse(settings_url)
    query_keys = uri.query.to_s.split("&").map { |pair| pair.split("=", 2).first }

    assert_equal "/preference/cookie/edit", uri.path
    assert_equal "jp", Rack::Utils.parse_query(uri.query).fetch("ri")
    assert_equal query_keys.uniq, query_keys
    assert_not_equal URI.parse("http://#{default_headers.fetch("Host")}").host, uri.host
  end
end
