# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::Sign::Up::InvitationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_email_statuses, :operator_visibilities

  setup do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    @org_sign_up_feature = FeatureFlags::REGISTRY.fetch(:sign_up_available_org).name
    @previous_org_sign_up_availability = Flipper.enabled?(@org_sign_up_feature)
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
    @previous_org_sign_up_availability ? Flipper.enable(@org_sign_up_feature) : Flipper.disable(@org_sign_up_feature)
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

  test "A29-9: ORG invitation acceptance is refused while Sign Up is blocked" do
    Flipper.disable(@org_sign_up_feature)
    registration_counts = [Operator.count, Bureau.count, AgentMembership.count]

    get new_auth_org_sign_up_invitation_url(invitation_code: @invitation.code, ri: "jp")

    assert_response :service_unavailable
    assert_nil response.headers["Location"]
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal registration_counts, [Operator.count, Bureau.count, AgentMembership.count]
    assert_not_predicate @invitation.reload, :consumed?
  end

  test "create preserves route and renders migration refusal without registration" do
    assert_no_difference [-> { Operator.count }, -> { Bureau.count }, -> { AgentMembership.count }] do
      post auth_org_sign_up_invitations_url(ri: "jp"),
           params: { invitation_code: @invitation.code, "cf-turnstile-response": "test" }
    end

    assert_response :unprocessable_content
    assert_equal "auth/org/sign/up/invitations/new", inertia_component
    assert_equal "Organization invitations are unavailable pending Bureau migration", inertia_props.fetch("form_error")
    assert_not_predicate @invitation.reload, :consumed?
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

  test "invitation existence expiry and consumption share one public refusal" do
    expired = OrganizationInvitation.create!(
      organization_id: 123, email: "expired-enumeration@example.test", invited_by: operators(:one),
      expires_at: 1.second.ago,
    )
    consumed = OrganizationInvitation.create!(
      organization_id: 123, email: "consumed-enumeration@example.test", invited_by: operators(:one),
      consumed_at: Time.current,
    )
    counts = [Operator.count, Bureau.count, AgentMembership.count]
    errors = []
    [@invitation.code, expired.code, consumed.code, "z" * 32, "", nil].each do |code|
      post auth_org_sign_up_invitations_url(ri: "jp"),
           params: { invitation_code: code, "cf-turnstile-response": "test" }

      assert_response :unprocessable_content
      assert_nil response.headers["Location"]
      errors << inertia_props.fetch("form_error")

      assert_equal counts, [Operator.count, Bureau.count, AgentMembership.count]
    end
    assert_equal [OrgInvitationService::MIGRATION_REQUIRED_MESSAGE], errors.uniq
    assert_not_predicate @invitation.reload, :consumed?
    assert_not_predicate expired.reload, :consumed?
    assert_predicate consumed.reload, :consumed?
  end
end
