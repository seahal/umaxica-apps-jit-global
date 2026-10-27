# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AcceptanceWu34RegisteredCommitFailureTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host!(@host)
    https!
    @origin_headers = {
      "Origin" => "https://#{@host}",
      "Sec-Fetch-Site" => "same-origin",
    }
    @turnstile_state = [
      TurnstileVerifierStub.enabled,
      TurnstileVerifierStub.response,
      TurnstileVerifierStub.challenge_enabled,
      TurnstileVerifierStub.challenge_response,
    ]
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @feature_states =
      %i(sign_up_available_com sign_in_available_com).to_h do |feature|
        name = FeatureFlags::REGISTRY.fetch(feature).name
        [name, Flipper.enabled?(name)]
      end
    @feature_states.each_key { |name| Flipper.enable(name) }

    {
      VisitorStatus => VisitorStatus::DEFAULTS,
      VisitorTelephoneStatus => VisitorTelephoneStatus::DEFAULTS,
      VisitorPasskeyStatus => VisitorPasskeyStatus::DEFAULTS,
      VisitorSignInFlowState => VisitorSignInFlowState::DEFAULTS,
      VisitorSignUpFlowStatus => VisitorSignUpFlowStatus::DEFAULTS,
      VisitorSignUpFlowCleanupStatus => VisitorSignUpFlowCleanupStatus::DEFAULTS,
      VisitorSecretCredentialKind => VisitorSecretCredentialKind::DEFAULTS,
      VisitorSecretCredentialStatus => VisitorSecretCredentialStatus::DEFAULTS,
      VisitorTokenStatus => VisitorTokenStatus::DEFAULTS,
    }.each do |record_class, ids|
      ids.each { |id| record_class.find_or_create_by!(id: id) }
    end
    [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
    VisitorSecurityMode.insert_missing_fixed_ids!(VisitorSecurityMode::DEFAULTS)
    VisitorTokenDbscStatus.ensure_defaults!
  end

  teardown do
    TurnstileVerifierStub.enabled, TurnstileVerifierStub.response,
      TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = @turnstile_state
    @feature_states.each do |name, enabled|
      enabled ? Flipper.enable(name) : Flipper.disable(name)
    end
  end

  test "A34-5: graph failure after COM registration commit preserves sign-in and cleanup recovery" do
    client = OidcClientRegistry.find!("core-com-jp")
    signup_nonce = SecureRandom.urlsafe_base64(32)
    signup_parameters = {
      client_id: client.client_id,
      response_type: "code",
      scope: "openid profile",
      redirect_uri: client.redirect_uris_by_realm.fetch("visitor").first,
      prompt: "create",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
    }
    signup_issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
      surface: "com", intent: "sign_up", params: signup_parameters,
      base_browser_nonce: signup_nonce, base_token: nil,
    )
    signup_binding = VisitorAuthAdmissionBinding.find_by!(entry_ref: signup_issuance.handoff.reference)

    admit_auth_ceremony_entry!(
      auth_com_sign_up_path(ri: "jp"), reference: signup_binding.entry_ref,
    )

    assert_response :see_other
    get response.location, headers: @origin_headers

    assert_response :success
    telephone_number = "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
    post auth_com_sign_up_telephone_path(ri: "jp"), params: {
      visitor_telephone: {
        raw_number: telephone_number,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      },
      "cf-turnstile-response": "synthetic",
    }, headers: @origin_headers

    assert_response :redirect
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    flow = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))
    telephone = VisitorTelephone.find(flow.pending_contact_id)
    otp_transaction = VisitorTelephoneCeremonyTransaction.find_by!(
      telephone_candidate_ref: telephone.public_id,
    )
    delivery_job =
      enqueued_jobs.reverse.find do |job|
        next false unless job.fetch(:job) == Outbound::SmsDeliveryJob

        payload = OutboundSensitivePayload.decrypt_sms_delivery(
          job.fetch(:args).fetch(0).fetch("encrypted_payload"),
        )
        payload.fetch(:otp_binding)[3] == otp_transaction.transaction_id
      end
    sms_payload = OutboundSensitivePayload.decrypt_sms_delivery(
      delivery_job.fetch(:args).fetch(0).fetch("encrypted_payload"),
    )
    otp = sms_payload.fetch(:otp_code)

    patch auth_com_sign_up_check_telephone_otp_path(ri: "jp", fb: flow_binding), params: {
      visitor_telephone: { pass_code: otp },
    }, headers: @origin_headers

    assert_response :redirect
    flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    passkey_path = auth_com_sign_up_check_telephone_passkey_path(ri: "jp", fb: flow_binding)
    post passkey_path, headers: @origin_headers, as: :json

    assert_response :ok
    registration_options = response.parsed_body
    fake_client = WebAuthn::FakeClient.new("https://#{@host}", encoding: :base64url)
    registration = fake_client.create(
      challenge: registration_options.fetch("options").fetch("challenge"),
      rp_id: registration_options.fetch("options").fetch("rp").fetch("id"),
      user_verified: true,
    )
    patch passkey_path, params: {
      challenge_id: registration_options.fetch("challenge_id"),
      checkpoint_version: flow.reload.checkpoint_version,
      credential: registration,
      description: "Registered Commit Recovery Key",
    }, headers: @origin_headers, as: :json

    assert_response :created
    birthdate_target = URI.parse(response.parsed_body.fetch("redirect_url"))
    flow_binding = Rack::Utils.parse_query(birthdate_target.query).fetch("fb")
    get birthdate_target.to_s, headers: @origin_headers

    assert_response :success
    visitor = Visitor.find(telephone.visitor_id)
    registration_passkey = VisitorPasskey.find_by!(visitor_id: visitor.id)
    birthdate_path = auth_com_sign_up_check_telephone_birthdate_path(ri: "jp", fb: flow_binding)
    assert_raises(RuntimeError) do
      IdentityGraphProvisioner.stub(
        :call!, ->(surface:, principal:) { raise RuntimeError, "injected graph outage for #{surface}:#{principal.id}" },
      ) do
        patch birthdate_path, params: {
          requirement: "birthdate",
          birthdate: "2000-01-01",
          checkpoint_version: flow.reload.checkpoint_version,
        }, headers: @origin_headers
      end
    end

    assert_equal VisitorStatus::ACTIVE, visitor.reload.status_id
    assert_predicate visitor, :sign_in_allowed?
    assert_equal VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP, telephone.reload.visitor_telephone_status_id
    assert_equal VisitorPasskeyStatus::ACTIVE, registration_passkey.reload.status_id
    assert_predicate flow.reload, :sign_up_checkpoint_pending?
    assert_not VisitorIdentity.exists?(source_record_id: visitor.id)

    expired_at = VisitorSignUpFlow.database_now - 1.second
    flow.update_columns(issued_at: expired_at - 1.second, expires_at: expired_at)
    SignUpExpiryJob.perform_now

    assert_predicate flow.reload, :sign_up_expired?
    assert_predicate flow, :cleanup_completed?
    assert_equal VisitorStatus::ACTIVE, visitor.reload.status_id
    assert_equal VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP, telephone.reload.visitor_telephone_status_id
    assert_equal VisitorPasskeyStatus::ACTIVE, registration_passkey.reload.status_id

    signin_nonce = SecureRandom.urlsafe_base64(32)
    signin_parameters = signup_parameters.except(:prompt).merge(
      state: SecureRandom.urlsafe_base64(32), nonce: SecureRandom.urlsafe_base64(32),
    )
    signin_issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
      surface: "com", intent: "sign_in", params: signin_parameters,
      base_browser_nonce: signin_nonce, base_token: nil,
    )
    signin_binding = VisitorAuthAdmissionBinding.find_by!(entry_ref: signin_issuance.handoff.reference)
    signin_entry_parameters = { entry_ref: signin_binding.entry_ref, ri: "jp" }
    get auth_com_sign_in_path(ri: "jp"), params: signin_entry_parameters, headers: @origin_headers

    assert_response :see_other
    get response.location, headers: @origin_headers

    assert_response :see_other
    signin_binding.reload.confirm_base!(base_token: nil, browser_digest: signin_binding.base_browser_digest)
    get auth_com_sign_in_path(ri: "jp"), params: signin_entry_parameters, headers: @origin_headers

    assert_response :see_other
    get new_auth_com_sign_in_passkey_path(ri: "jp"), headers: @origin_headers

    assert_response :success
    post auth_com_sign_in_passkey_options_path(ri: "jp"), params: {
      identifier: telephone.number,
      "cf-turnstile-response": "synthetic",
    }, headers: @origin_headers

    assert_response :ok
    signin_options = response.parsed_body
    assertion = fake_client.get(
      challenge: signin_options.fetch("options").fetch("challenge"),
      user_verified: true,
      sign_count: 1,
      user_handle: visitor.webauthn_user_handle,
    )
    post auth_com_sign_in_passkey_verification_path(ri: "jp"), params: {
      challenge_id: signin_options.fetch("challenge_id"),
      credential: assertion,
    }, headers: @origin_headers

    assert_response :ok
    assert_equal "ok", response.parsed_body.fetch("status")
    signin_ceremony = VisitorAuthCeremonySession.find(signin_binding.reload.admitted_auth_ceremony_session_id)

    assert_predicate signin_ceremony, :authentication_evidence_recorded?

    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor.reload)
    graph_identity = VisitorIdentity.find_by!(source_record_id: visitor.id)

    assert_equal BaseSelectorBootstrapAuthority::ISSUER, graph_identity.issuer
    assert_equal visitor.public_id, graph_identity.subject
  end
end
