# typed: false
# frozen_string_literal: true

require "test_helper"

# Corporate-surface sign-up checkpoint chain for a telephone registration:
# OTP verification, the passkey checkpoint, and the direct birthdate continuation.
class AuthComUpCheckpointTelephoneControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! @host
    @headers = { "Host" => @host, "HTTPS" => "on", "X-CSRF-Token" => "test-csrf-token" }.freeze
    cookies["csrf_token"] = "test-csrf-token"
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    VisitorSignInFlowState::DEFAULTS.each { |id| VisitorSignInFlowState.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    https!
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "com", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    binding = VisitorAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    get(auth_com_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference })

    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    admission_headers = { "Origin" => "https://#{request.host}", "Sec-Fetch-Site" => "same-origin" }
    post(
      "/ceremony_bindings", params: { entry_ref: issuance.reference, ri: "jp", authenticity_token: csrf },
                            headers: admission_headers,
    )

    assert_response :see_other
    binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get(auth_com_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference })

    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      auth_com_sign_up_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf },
                                       headers: admission_headers,
    )

    assert_response :see_other

    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      [
        VisitorTelephoneStatus::UNVERIFIED,
        VisitorTelephoneStatus::VERIFIED,
        VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP,
      ].each { |id| VisitorTelephoneStatus.find_or_create_by!(id: id) }
      VisitorPasskeyStatus::DEFAULTS.each { |id| VisitorPasskeyStatus.find_or_create_by!(id: id) }
      VisitorSecretCredentialKind::DEFAULTS.each { |id| VisitorSecretCredentialKind.find_or_create_by!(id: id) }
      VisitorSecretCredentialStatus::DEFAULTS.each { |id| VisitorSecretCredentialStatus.find_or_create_by!(id: id) }
      VisitorTokenDbscStatus.ensure_defaults!
      VisitorTokenStatus::DEFAULTS.each { |id| VisitorTokenStatus.find_or_create_by!(id: id) }
    end
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "otp checkpoint rejects a wrong code and keeps the telephone unverified" do
    post auth_com_sign_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: { raw_number: "+819012390001", confirm_policy: "1", confirm_using_mfa: "1" },
           "cf-turnstile-response": "test",
         }, headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    telephone = VisitorTelephone.order(:created_at).last
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    code =
      OutboundSensitivePayload.decrypt_sms_delivery(
        job.fetch(:args).fetch(0).fetch("encrypted_payload"),
      ).fetch(:otp_code)
    wrong_code = (code == "000000") ? "000001" : "000000"

    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp", fb: @flow_binding),
          params: { visitor_telephone: { pass_code: wrong_code } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
                 telephone.reload.visitor_telephone_status_id
  end

  test "otp checkpoint verifies the telephone and hands the ceremony to the guard step" do
    post auth_com_sign_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: { raw_number: "+819012390002", confirm_policy: "1", confirm_using_mfa: "1" },
           "cf-turnstile-response": "test",
         }, headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    telephone = VisitorTelephone.order(:created_at).last
    transaction_ref =
      VisitorTelephoneCeremonyTransaction.find_by!(
        telephone_candidate_ref: telephone.public_id,
      ).transaction_id
    queued =
      enqueued_jobs.reverse.find do |job|
        next false unless job.fetch(:job) == Outbound::SmsDeliveryJob

        payload = OutboundSensitivePayload.decrypt_sms_delivery(job.fetch(:args).fetch(0).fetch("encrypted_payload"))
        payload.fetch(:otp_binding)[3] == transaction_ref
      end
    code =
      OutboundSensitivePayload.decrypt_sms_delivery(
        queued.fetch(:args).fetch(0).fetch("encrypted_payload"),
      ).fetch(:otp_code)

    patch auth_com_sign_up_check_telephone_otp_url(ri: "jp", fb: @flow_binding),
          params: { visitor_telephone: { pass_code: code } }, headers: @headers

    assert_redirected_to auth_com_sign_up_guard_telephone_url(ri: "jp", fb: @flow_binding)
    cycle = VisitorSignUpFlow.order(:id).find_by!(
      principal_id: telephone.visitor_id, pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )

    assert cycle.requirement_cleared?(:otp)
  end

  test "passkey checkpoint answers not found without a sign-up registration session" do
    post auth_com_sign_up_check_telephone_passkey_url(ri: "jp", fb: @flow_binding), headers: @headers, as: :json

    assert_response :not_found
  end

  test "passkey checkpoint issues a registration challenge for the pending visitor" do
    advance_to_passkey_checkpoint!("+819012390003")

    post auth_com_sign_up_check_telephone_passkey_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :ok
    body = response.parsed_body

    assert_predicate body["challenge_id"], :present?
    assert_predicate body.dig("options", "challenge"), :present?
    assert_equal "registration", session[:passkey_challenges][body["challenge_id"]]["purpose"]
    assert_predicate body.dig("options", "user", "id"), :present?
  end

  test "passkey checkpoint page exposes the checkpoint version and direct birthdate continuation" do
    telephone = advance_to_passkey_checkpoint!("+819012390004")
    cycle = VisitorSignUpFlow.order(:id).find_by!(
      principal_id: telephone.visitor_id, pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )

    get auth_com_sign_up_check_telephone_passkey_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :success
    props = inertia_props

    assert_equal cycle.checkpoint_version, props.fetch("checkpoint_version")
    assert_equal auth_com_sign_up_check_telephone_birthdate_path(ri: "jp", fb: @flow_binding),
                 props.fetch("success_redirect_url")
  end

  test "registered passkey advances directly to birthdate without issuing a LOGIN credential" do
    telephone = advance_to_passkey_checkpoint!("+819012390005")
    cycle = VisitorSignUpFlow.order(:id).find_by!(
      principal_id: telephone.visitor_id, pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )
    register_signup_passkey!(cycle, "com_signup_direct_birthdate")

    assert cycle.reload.requirement_cleared?(:passkey)
    assert_empty telephone.visitor.visitor_secret_credentials.where(
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
    )

    get auth_com_sign_up_check_telephone_birthdate_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :success
    assert_predicate inertia_props.fetch("birthdate"), :present?
    assert_not_includes inertia_props.keys, "passcode"
  end

  test "birthdate checkpoint cancels the ceremony on delete" do
    telephone = advance_to_passkey_checkpoint!("+819012390007")
    cycle = VisitorSignUpFlow.order(:id).find_by!(
      principal_id: telephone.visitor_id, pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )
    register_signup_passkey!(cycle, "com_signup_cancel_birthdate")

    delete auth_com_sign_up_check_telephone_birthdate_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :redirect
    assert_nil session[:auth_com_up_sequence_id]
  end

  test "birthdate checkpoint finalizes the corporate sign-up for an eligible visitor" do
    telephone = advance_to_passkey_checkpoint!("+819012390011")
    cycle = VisitorSignUpFlow.order(:id).find_by!(
      principal_id: telephone.visitor_id, pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )
    register_signup_passkey!(cycle, "com_signup_birthdate")
    patch auth_com_sign_up_check_telephone_birthdate_url(ri: "jp", fb: @flow_binding),
          params: {
            requirement: "birthdate",
            birthdate: "2000-01-01",
            checkpoint_version: cycle.reload.checkpoint_version,
          }, headers: @headers

    assert_response :redirect
    assert cycle.reload.requirement_cleared?(:birthdate)
  end

  test "birthdate checkpoint answers the age-restricted page and fails the ceremony for a minor" do
    telephone = advance_to_passkey_checkpoint!("+819012390012")
    cycle = VisitorSignUpFlow.order(:id).find_by!(
      principal_id: telephone.visitor_id, pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )
    register_signup_passkey!(cycle, "com_signup_minor")
    patch auth_com_sign_up_check_telephone_birthdate_url(ri: "jp", fb: @flow_binding),
          params: {
            requirement: "birthdate",
            birthdate: Time.zone.today.prev_year(10).to_s,
            checkpoint_version: cycle.reload.checkpoint_version,
          }, headers: @headers

    assert_response :success
    assert_equal "auth/com/sign/up/checkpoints/age_restricted", inertia_component
    assert_equal I18n.t("sign.com.registration.checkpoint.age_restricted"), inertia_props.fetch("message")
    assert_not cycle.reload.requirement_cleared?(:birthdate)
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "birthdate checkpoint page lists the outstanding requirement for the ceremony" do
    telephone = advance_to_passkey_checkpoint!("+819012390013")
    cycle = VisitorSignUpFlow.order(:id).find_by!(
      principal_id: telephone.visitor_id, pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )
    register_signup_passkey!(cycle, "com_signup_checkpoint_page")
    get auth_com_sign_up_check_telephone_birthdate_url(ri: "jp", fb: @flow_binding), headers: @headers

    assert_response :success
    assert_equal "auth/com/sign/up/checkpoints/show", inertia_component
    assert_predicate inertia_props.fetch("birthdate"), :present?
    # The cancellation endpoint names the step the visitor is standing on; there is no step-less
    # check path, so a missing step would raise while building the props.
    assert_equal auth_com_sign_up_check_telephone_birthdate_path(ri: "jp", fb: @flow_binding),
                 inertia_props.fetch("cancellation").fetch("action")
  end

  private

  # Drives the public ceremony endpoints up to the point where the passkey
  # checkpoint is the current step, which is the precondition every checkpoint
  # assertion below needs.
  def advance_to_passkey_checkpoint!(number)
    post(
      auth_com_sign_up_telephone_url(ri: "jp"),
      params: {
        visitor_telephone: { raw_number: number, confirm_policy: "1", confirm_using_mfa: "1" },
        "cf-turnstile-response": "test",
      }, headers: @headers,
    )

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    telephone = VisitorTelephone.order(:created_at).last
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == Outbound::SmsDeliveryJob }
    code =
      OutboundSensitivePayload.decrypt_sms_delivery(
        job.fetch(:args).fetch(0).fetch("encrypted_payload"),
      ).fetch(:otp_code)
    patch(
      auth_com_sign_up_check_telephone_otp_url(ri: "jp", fb: @flow_binding),
      params: {
        visitor_telephone: { pass_code: code },
      }, headers: @headers,
    )
    get(auth_com_sign_up_guard_telephone_url(ri: "jp", fb: @flow_binding), headers: @headers)
    telephone.reload
  end

  def register_signup_passkey!(cycle, suffix)
    post(auth_com_sign_up_check_telephone_passkey_url(ri: "jp", fb: @flow_binding), headers: @headers)
    challenge_id = response.parsed_body["challenge_id"]
    credential = Object.new
    credential.define_singleton_method(:id) { "#{suffix}_webauthn_id" }
    credential.define_singleton_method(:public_key) { "#{suffix}_public_key" }
    credential.define_singleton_method(:sign_count) { 1 }
    credential.define_singleton_method(:verify) { |_challenge| true }
    registration_context = Struct.new(
      :webauthn_id, :sign_count, :aaguid, :transports, :backup_eligible, :backup_state,
      :authenticator_attachment,
    ).new("#{suffix}_webauthn_id", 1)

    Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
      WebAuthn::Credential.stub(:from_create, credential) do
        patch(
          auth_com_sign_up_check_telephone_passkey_url(ri: "jp", fb: @flow_binding),
          params: {
            challenge_id: challenge_id,
            checkpoint_version: cycle.reload.checkpoint_version,
            credential: {
              id: "#{suffix}_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "Signup Passkey",
          }, headers: @headers,
        )
      end
    end

    assert_response :created
    assert_equal auth_com_sign_up_check_telephone_birthdate_path(ri: "jp", fb: @flow_binding),
                 response.parsed_body.fetch("redirect_url")
  end
end
