# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::Sign::Up::InvitationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_email_statuses, :operator_visibilities

  setup do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @invitation = OrganizationInvitation.create!(
      organization_id: 123,
      email: "invitee-controller-#{SecureRandom.hex(8)}@example.com",
      invited_by: operators(:one),
      role_id: 7,
    )
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "new renders invitation acceptance form" do
    get new_auth_org_sign_up_invitation_url(invitation_code: @invitation.code, ri: "jp")

    assert_response :success
    assert_equal "auth/org/sign/up/invitations/new", inertia_component
    assert_equal @invitation.code, inertia_props.fetch("invitation_code")
    assert_equal I18n.t("sign.org.up.invitations.form.invitation_code"),
                 inertia_props.fetch("invitation_code_label")
    # The visible Turnstile widget draws itself and writes the token into the form.
    assert_equal "render", inertia_props.fetch("turnstile").fetch("mode")
  end

  test "create accepts invitation and redirects to sign in" do
    assert_difference -> { Operator.count }, 1 do
      post auth_org_sign_up_invitations_url(ri: "jp"),
           params: { invitation_code: @invitation.code, "cf-turnstile-response": "test" }
    end

    assert_redirected_to auth_org_sign_in_path(ri: "jp")
    assert_predicate @invitation.reload, :consumed?
    assert_nil flash[:notice]
  end

  test "create renders new for invalid invitation" do
    assert_no_difference -> { Operator.count } do
      post auth_org_sign_up_invitations_url(ri: "jp"),
           params: { invitation_code: "missing", "cf-turnstile-response": "test" }
    end

    assert_response :unprocessable_content
    assert_not_nil inertia_props.fetch("form_error")
    assert_nil flash[:alert]
  end

  test "create rejects failed turnstile before accepting invitation" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_no_difference -> { Operator.count } do
      post auth_org_sign_up_invitations_url(ri: "jp"),
           params: { invitation_code: @invitation.code, "cf-turnstile-response": "test" }
    end

    assert_response :unprocessable_content
    assert_not_predicate @invitation.reload, :consumed?
    assert_not_nil inertia_props.fetch("form_error")
    assert_nil flash[:alert]
  end
end
