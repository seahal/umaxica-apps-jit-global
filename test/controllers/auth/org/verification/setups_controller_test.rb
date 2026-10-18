# frozen_string_literal: true

require "test_helper"

class Auth::Org::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens

  test "an admitted bootstrap shows the passkey registration method and cancellation, never a back link" do
    # An operator fixture that holds no passkey: bootstrap is first registration only.
    actor = operators(:none_staff)
    token = OperatorToken.create!(staff: actor, root_login_established_at: Time.current)
    issuance =
      begin
        admission_issuance = BaseStepUpAdmissionIssuer.call!(
          actor: actor,
          token: token,
          requirement: StepUpRequirement.new(
            scope: "settings_email", purpose: "bootstrap", step_up_required: false,
            phishing_resistant_required: false, user_verification_required: false,
            full_reauthentication_required: false, actor_ref: actor.public_id,
            resource_ref: nil, tenant_ref: nil,
            allowed_methods: [:passkey], audience: "step_up:org", session_binding: token.public_id,
            token_binding: token.public_id, require_session_binding: true, ttl: 15.minutes,
          ),
          return_to: "/identity/emails",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: token,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: admission_issuance.transaction.surface, reference: admission_issuance.reference,
        )
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: token,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_issuance.transaction.surface,
            entry_ref: admission_issuance.reference,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          ),
        )
        admission_auth_host = {
          "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
          "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
          "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
        }.fetch(admission_issuance.transaction.surface)
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        # Rack::Test::CookieJar#merge mutates the jar and has no merge! counterpart.
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_raw_sid)}",
          URI.parse("https://#{admission_auth_host}/"),
        )
        admission_issuance
      end
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    get new_auth_org_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_org_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other

    get new_auth_org_verification_setup_path(ri: "jp")

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal [new_auth_org_verification_registration_passkey_path(ri: "jp")],
                 props.fetch("methods").map { |method| method.fetch("href") }
    assert_not props.key?("back_link")
    assert_equal auth_org_verification_cancellation_path(ri: "jp"), props.fetch("cancel").fetch("action")
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  test "the setup page is refused without an admitted bootstrap and never redirects to sign-in" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    get new_auth_org_verification_setup_path(ri: "jp")

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil response.headers["Location"]
  end
end
