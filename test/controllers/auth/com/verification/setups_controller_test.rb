# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "an admitted bootstrap shows the registration methods and cancellation, never a back link" do
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    actor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    token = VisitorToken.create!(
      visitor: actor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      root_login_established_at: Time.current,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_telephone", purpose: "bootstrap", step_up_required: false,
        allowed_methods: [:passkey], audience: "step_up:com", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true, ttl: 15.minutes,
      ), return_to: "/identity/telephones",
    )
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    get new_auth_com_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_com_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other

    get new_auth_com_verification_setup_path(ri: "jp")

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_includes props.fetch("methods").map { |method| method.fetch("href") },
                    new_auth_com_settings_passkey_path(ri: "jp")
    assert_not props.key?("back_link")
    assert_equal auth_com_verification_cancellation_path(ri: "jp"), props.fetch("cancel").fetch("action")
    assert_equal "post", props.fetch("cancel").fetch("method")
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  test "the setup page is refused without an admitted bootstrap and never redirects to sign-in" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")

    get new_auth_com_verification_setup_path(ri: "jp")

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil response.headers["Location"]
  end
end
