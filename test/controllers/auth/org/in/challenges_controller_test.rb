# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

# The staff MFA challenge hub. It offers the passkey ceremony only when the
# pending operator actually holds an active passkey, so a factor the server
# would reject is never advertised.
class Auth::Org::Sign::In::ChallengesControllerTest < ActionDispatch::IntegrationTest
  include OrgEntraFirstStageHelper

  fixtures :operators, :operator_secret_credentials, :operator_statuses,
           :operator_secret_credential_statuses, :operator_secret_credential_kinds,
           :operator_token_binding_methods, :operator_token_kinds, :operator_token_statuses,
           :operator_token_dbsc_statuses, :operator_email_statuses, :operator_passkey_statuses

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! @host
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @staff = operators(:sample_staff)
    @staff.update!(status_id: OperatorStatus::ACTIVE, mfa_level_enabled: true)
    OperatorToken.where(staff_id: @staff.id).delete_all
    @staff.staff_secret_credentials.destroy_all
    @secret_credential, @raw_secret_credential = OperatorSecretCredential.issue!(
      name: "Sample login",
      staff_id: @staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )
    OperatorEmail.find_or_create_by!(staff: @staff, address: "org_challenge_hub@example.com") do |email|
      email.staff_email_status_id = OperatorEmailStatus::VERIFIED
    end
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "show redirects to sign in when no MFA is pending" do
    get auth_org_sign_in_challenge_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_org_sign_in_path(ri: "jp")
  end

  test "show offers the passkey ceremony to an operator holding an active passkey" do
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: Base64.urlsafe_encode64("org_challenge_passkey_id", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "org_challenge_key",
      description: "MFA Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_secret_path(ri: "jp"), params: {
      secret_credential_login_form: {
        secret_credential_value: @raw_secret_credential,
      },
      "cf-turnstile-response": "test_token",
    }

    assert_redirected_to auth_org_sign_in_challenge_path(ri: "jp")

    follow_redirect!

    assert_response :success
    assert_equal "auth/org/sign/in/challenges/show", inertia_component
    assert_includes inertia_props.fetch("methods").map { |method| method.fetch("key") }, "passkey"
    assert_nil inertia_props.fetch("no_methods_notice")
    assert_nil inertia_props.fetch("back_link")
  end

  test "show tells an operator with no usable factor that no method is available" do
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_secret_path(ri: "jp"), params: {
      secret_credential_login_form: {
        secret_credential_value: @raw_secret_credential,
      },
      "cf-turnstile-response": "test_token",
    }

    assert_redirected_to auth_org_sign_in_challenge_path(ri: "jp")

    follow_redirect!

    assert_response :success
    assert_empty inertia_props.fetch("methods")
    assert_predicate inertia_props.fetch("no_methods_notice"), :present?
    assert_equal auth_org_sign_in_path(ri: "jp"), inertia_props.fetch("back_link").fetch("href")
  end
end
