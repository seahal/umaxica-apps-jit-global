# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# The secret-credential stage of normal org sign-in, reached only after Entra ID
# has selected the operator. There is no identifier here any more: the tests that
# used to submit one now prove that the operator comes from the pending Entra
# transaction instead.
class Auth::Org::Sign::In::SecretsControllerTest < ActionDispatch::IntegrationTest
  include OrgEntraFirstStageHelper

  fixtures :operators, :operator_secret_credentials, :operator_statuses, :operator_secret_credential_statuses,
           :operator_secret_credential_kinds, :operator_token_binding_methods, :operator_token_kinds,
           :operator_token_statuses, :operator_token_dbsc_statuses, :operator_email_statuses

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! @host
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @staff = operators(:sample_staff)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    OperatorToken.where(staff_id: @staff.id).delete_all
    @staff.staff_secret_credentials.destroy_all
    @secret_credential, @raw_secret_credential = OperatorSecretCredential.issue!(
      name: "Sample login",
      staff_id: @staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )
    OperatorEmail.find_or_create_by!(staff: @staff, address: "sample_staff_sign_in@example.com") do |email|
      email.staff_email_status_id = OperatorEmailStatus::VERIFIED
    end
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "should get new" do
    complete_org_entra_first_stage!(@staff)

    get new_auth_org_sign_in_secret_url(ri: "jp")

    assert_response :success
    assert_equal "auth/org/sign/in/secrets/new", inertia_component
    assert_not inertia_props.key?("identifier"), "the operator comes from the Entra transaction"
    assert_equal "jp", inertia_props.fetch("hidden_fields").fetch("ri")
    assert_equal auth_org_sign_in_path(ri: "jp"), inertia_props.fetch("back_link").fetch("href")
  end

  test "new sends the operator back to the entry when no entra transaction is pending" do
    get new_auth_org_sign_in_secret_url(ri: "jp")

    assert_redirected_to auth_org_sign_in_path(ri: "jp")
  end

  test "create is refused without a pending entra transaction" do
    post auth_org_sign_in_secret_url(ri: "jp"),
         params: {
           secret_credential_login_form: { secret_credential_value: @raw_secret_credential },
           "cf-turnstile-response": "test_token",
         }

    assert_response :unprocessable_content
    assert_nil @secret_credential.reload.last_used_at
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "a secret belonging to another operator does not authenticate the entra-selected operator" do
    other_staff = operators(:reserved_staff)
    _other_credential, other_raw = OperatorSecretCredential.issue!(
      name: "Other login",
      staff_id: other_staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: {
           secret_credential_login_form: { secret_credential_value: other_raw },
           "cf-turnstile-response": "test_token",
         }

    assert_response :unprocessable_content
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
    assert_equal 0, OperatorToken.where(staff_id: other_staff.id).count
  end

  test "create signs in the entra-selected operator under the normal authentication context" do
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :redirect
    assert_includes response.headers["Location"], auth_org_sign_in_check_path(ri: "jp")
    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
    assert_predicate @secret_credential.reload.last_used_at, :present?

    token = OperatorToken.where(staff_id: @staff.id).order(:id).last

    assert_equal "normal", token.authentication_context_value.to_s
  end

  test "create falls back to jp when ri is missing" do
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_secret_url,
         params: {
           secret_credential_login_form: {
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :redirect
    assert_includes response.headers["Location"], auth_org_sign_in_check_path(ri: "jp")
  end

  test "create canonicalizes invalid ri" do
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_secret_url(ri: "https://evil.example"),
         params: {
           secret_credential_login_form: {
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :redirect
    assert_includes response.headers["Location"], auth_org_sign_in_secret_url(ri: "jp")
    assert_no_match(/evil\.example/, response.headers["Location"])
  end

  # A permanent secret is not consumed by use, but a second ceremony inside an
  # authenticated session is refused: starting a sign-in from a signed-in browser
  # would be a mode switch, and the only supported answer is to sign out first.
  test "create keeps the permanent secret reusable and refuses a repeated ceremony in the same session" do
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: {
           secret_credential_login_form: { secret_credential_value: @raw_secret_credential },
           "cf-turnstile-response": "test_token",
         }

    assert_response :redirect

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: {
           secret_credential_login_form: { secret_credential_value: @raw_secret_credential },
           "cf-turnstile-response": "test_token",
         }

    assert_response :conflict
    assert_equal "Sign-in is unavailable while authenticated.", response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
  end

  test "create is refused when the challenge verification fails" do
    complete_org_entra_first_stage!(@staff)

    TurnstileVerifierStub.challenge_response = { "success" => false }

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :unprocessable_content
    assert_nil @secret_credential.reload.last_used_at
  end

  test "an unexpected failure while verifying the secret credential is reported without leaking the cause" do
    complete_org_entra_first_stage!(@staff)

    exploding = ->(*) { raise IOError, "verifier unavailable" }

    OperatorSecretCredential.stub(:allowed_for_secret_credential_sign_in, exploding) do
      post auth_org_sign_in_secret_url(ri: "jp"),
           params: {
             secret_credential_login_form: {
               secret_credential_value: @raw_secret_credential,
             },
             "cf-turnstile-response": "test_token",
           }
    end

    assert_response :unprocessable_content
    assert_not_includes response.body, "verifier unavailable"
  end

  test "create rejects blank form" do
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
  end

  test "create rejects invalid secret_credential" do
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             secret_credential_value: "wrong-secret_credential-value-000000000000",
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
  end

  test "create rejects non login secret_credential for secret_credential login" do
    complete_org_entra_first_stage!(@staff)

    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::NOTHING)
    @secret_credential.update!(staff_secret_kind_id: OperatorSecretCredentialKind::NOTHING)

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             secret_credential_value: @raw_secret_credential,
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
  end

  test "a reserved operator cannot get past the entra stage, so the secret stage is unreachable" do
    reserved_staff = operators(:reserved_staff)
    OperatorSecretCredential.issue!(
      name: "Reserved login",
      staff_id: reserved_staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )

    complete_org_entra_first_stage!(reserved_staff)

    assert_response :unprocessable_content

    get new_auth_org_sign_in_secret_url(ri: "jp")

    assert_redirected_to auth_org_sign_in_path(ri: "jp")
  end

  test "a withdrawn operator cannot get past the entra stage" do
    @staff.update!(status_id: OperatorStatus::ACTIVE, withdrawn_at: Time.current)
    secret_credential, = OperatorSecretCredential.issue!(
      name: "Withdrawn login",
      staff_id: @staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )

    complete_org_entra_first_stage!(@staff)

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, secret_credential.reload.staff_secret_status_id
  end

  test "create renders invalid when log_in returns non-success status" do
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             secret_credential_value: "wrong-secret_credential",
           },
         }

    assert_response :unprocessable_content
    assert_includes inertia_props.fetch("errors"),
                    I18n.t("sign.org.authentication.secret_credential.create.invalid")
  end

  test "create rejects direct secret credential login when logical staff limit is reached despite rotated rows" do
    complete_org_entra_first_stage!(@staff)

    create_rotated_active_staff_session(@staff, rotations: 4)

    post auth_org_sign_in_secret_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_includes [302, 422], response.status
    assert_equal 0, OperatorToken.where(staff_id: @staff.id, staff_token_status_id: OperatorTokenStatus::RESTRICTED).count
  end

  private

  def create_rotated_active_staff_session(staff, rotations:)
    token = OperatorToken.create!(staff: staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = SignRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
    end
  end
end
