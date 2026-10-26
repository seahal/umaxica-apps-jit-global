# typed: false
# frozen_string_literal: true

require "test_helper"

# Phase regression contract for the com email sign-up ceremony, exercised through the public HTTP
# boundary. The refusal body is fixed Japanese customer copy required by the contract, so it is
# asserted literally here.
class SignUpPhaseRegressionComTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  REFUSAL_BODY = "戻るはだめです"

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSecretCredentialKind::DEFAULTS.each { |id| VisitorSecretCredentialKind.find_or_create_by!(id: id) }
    VisitorSecretCredentialStatus::DEFAULTS.each { |id| VisitorSecretCredentialStatus.find_or_create_by!(id: id) }
    host! @host
    https!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    issuance = OidcTestEntry.issue!(
      surface: "com", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    admit_auth_ceremony_entry!(
      auth_com_sign_up_path, reference: issuance.reference, params: { ri: "jp" },
    )

    assert_response :see_other
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "reloading the current otp phase with its flow binding renders it again without changing the flow" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-reload@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    flow = VisitorSignUpFlow.order(:created_at).last

    get otp_url

    assert_response :success

    get otp_url

    assert_response :success
    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, flow.reload.status_id
  end

  test "get of the earlier otp phase after it was cleared is refused with 409 and leaves the flow unchanged" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-past-get@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    candidate = VisitorEmail.order(:created_at).last
    delivery =
      enqueued_jobs.reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        payload = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last.fetch(:params)
        payload.fetch(:public_id) == candidate.public_id
      end

    assert_not_nil delivery
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: payload.fetch(:sign_up_email_transaction_ref),
    )
    otp_data = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    assert_equal candidate.public_id, transaction.email_candidate_ref
    assert_equal transaction.otp_generation, payload.fetch(:sign_up_email_otp_generation)
    patch otp_url,
          params: { visitor_email: { pass_code: otp_data } }
    flow = VisitorSignUpFlow.order(:created_at).last
    updated_at = flow.updated_at

    get otp_url

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
    assert_equal VisitorSignUpFlowStatus::CHECKPOINT_PENDING, flow.reload.status_id
    assert_equal updated_at, flow.updated_at
  end

  test "get of the later birthdate phase before the otp is cleared is refused with 409 and leaves the flow unchanged" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-future-get@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    flow = VisitorSignUpFlow.order(:created_at).last

    get auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: binding)

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, flow.reload.status_id
  end

  test "mutation from the earlier otp phase halts the active flow and issues no new otp" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-past-post@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    candidate = VisitorEmail.order(:created_at).last
    delivery =
      enqueued_jobs.reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        payload = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last.fetch(:params)
        payload.fetch(:public_id) == candidate.public_id
      end

    assert_not_nil delivery
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: payload.fetch(:sign_up_email_transaction_ref),
    )
    otp_data = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    assert_equal candidate.public_id, transaction.email_candidate_ref
    assert_equal transaction.otp_generation, payload.fetch(:sign_up_email_otp_generation)
    patch otp_url,
          params: { visitor_email: { pass_code: otp_data } }
    flow = VisitorSignUpFlow.order(:created_at).last
    deliveries_before = ActionMailer::Base.deliveries.size

    post otp_url

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal VisitorSignUpFlowStatus::HALTED, flow.reload.status_id
    assert_equal deliveries_before, ActionMailer::Base.deliveries.size
  end

  test "mutation from the later birthdate phase before the otp is cleared halts the active flow" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-future-patch@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    flow = VisitorSignUpFlow.order(:created_at).last

    patch auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: binding),
          params: { requirement: "birthdate", checkpoint_version: flow.checkpoint_version, birthdate: "1990-01-15" }

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal VisitorSignUpFlowStatus::HALTED, flow.reload.status_id
  end

  test "a halted flow stays halted and issues no session when its current-phase form is submitted again" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-halted-retry@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    binding = Rack::Utils.parse_query(URI.parse(otp_url).query).fetch("fb")
    candidate = VisitorEmail.order(:created_at).last
    delivery =
      enqueued_jobs.reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        payload = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last.fetch(:params)
        payload.fetch(:public_id) == candidate.public_id
      end

    assert_not_nil delivery
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: payload.fetch(:sign_up_email_transaction_ref),
    )
    otp_data = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    assert_equal candidate.public_id, transaction.email_candidate_ref
    assert_equal transaction.otp_generation, payload.fetch(:sign_up_email_otp_generation)
    patch otp_url,
          params: { visitor_email: { pass_code: otp_data } }
    flow = VisitorSignUpFlow.order(:created_at).last
    post otp_url
    tokens_before = VisitorToken.count
    sign_in_flows_before = VisitorSignInFlow.count

    patch auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: binding),
          params: { requirement: "birthdate",
                    checkpoint_version: flow.reload.checkpoint_version,
                    birthdate: "1990-01-15", }

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal VisitorSignUpFlowStatus::HALTED, flow.reload.status_id
    assert_equal tokens_before, VisitorToken.count
    assert_equal sign_in_flows_before, VisitorSignInFlow.count
  end

  test "halting a flow for a phase violation records a durable audit event without the binding" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-audit@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    binding = Rack::Utils.parse_query(URI.parse(otp_url).query).fetch("fb")
    candidate = VisitorEmail.order(:created_at).last
    delivery =
      enqueued_jobs.reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        payload = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last.fetch(:params)
        payload.fetch(:public_id) == candidate.public_id
      end

    assert_not_nil delivery
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: payload.fetch(:sign_up_email_transaction_ref),
    )
    otp_data = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    assert_equal candidate.public_id, transaction.email_candidate_ref
    assert_equal transaction.otp_generation, payload.fetch(:sign_up_email_otp_generation)
    patch otp_url,
          params: { visitor_email: { pass_code: otp_data } }
    flow = VisitorSignUpFlow.order(:created_at).last

    post otp_url

    # Visitor authentication events use the existing client Chronicle owner.
    audit = ClientChronicle.where(event_id: ClientChronicleEvent::SIGN_FLOW_HALTED).order(:created_at).last

    assert_not_nil audit
    assert_equal flow.principal_id.to_s, audit.subject_id
    assert_equal "phase_regression", audit.context["reason_code"]
    assert_equal flow.public_id, audit.context["flow_public_id"]
    assert_equal "sign_up", audit.context["flow_kind"]
    assert_equal "com", audit.context["surface"]
    assert_not_includes audit.context.to_json, binding
    assert_not_includes audit.context.to_json, "phase-audit@example.com"
  end

  test "a second entry submit is refused while the first attempt is in progress" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-flow-a@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url_a = response.location
    binding_a = Rack::Utils.parse_query(URI.parse(otp_url_a).query).fetch("fb")
    candidate = VisitorEmail.order(:created_at).last
    delivery =
      enqueued_jobs.reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        payload = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last.fetch(:params)
        payload.fetch(:public_id) == candidate.public_id
      end

    assert_not_nil delivery
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: payload.fetch(:sign_up_email_transaction_ref),
    )
    otp_data = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    assert_equal candidate.public_id, transaction.email_candidate_ref
    assert_equal transaction.otp_generation, payload.fetch(:sign_up_email_otp_generation)
    patch otp_url_a, params: { visitor_email: { pass_code: otp_data } }
    flow = VisitorSignUpFlow.order(:created_at).last
    flow_facts = flow.attributes

    clear_enqueued_jobs
    assert_no_difference ["VisitorSignUpFlow.count", "VisitorEmail.count"] do
      post auth_com_sign_up_email_url(ri: "jp"),
           params: { :visitor_email => { raw_address: "phase-flow-b@example.com", confirm_policy: "1" },
                     "cf-turnstile-response" => "test", }
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.com.registration.email.create.contact_held")
    assert_no_enqueued_jobs only: OtpNotifierEmailDeliveryJob
    assert_equal flow_facts, flow.reload.attributes

    patch auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: binding_a),
          params: { requirement: "birthdate", checkpoint_version: flow.checkpoint_version, birthdate: "1990-01-15" }

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal flow_facts, flow.reload.attributes
  end

  test "a second tab that submits the otp after the first tab advanced the flow halts it before finalization" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-two-tabs@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    candidate = VisitorEmail.order(:created_at).last
    delivery =
      enqueued_jobs.reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        payload = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last.fetch(:params)
        payload.fetch(:public_id) == candidate.public_id
      end

    assert_not_nil delivery
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: payload.fetch(:sign_up_email_transaction_ref),
    )
    otp_data = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    assert_equal candidate.public_id, transaction.email_candidate_ref
    assert_equal transaction.otp_generation, payload.fetch(:sign_up_email_otp_generation)
    pass_code = otp_data
    patch otp_url, params: { visitor_email: { pass_code: pass_code } }
    flow = VisitorSignUpFlow.order(:created_at).last

    patch otp_url, params: { visitor_email: { pass_code: pass_code } }

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal VisitorSignUpFlowStatus::HALTED, flow.reload.status_id
  end

  test "a stale page submitted after finalization is refused and does not delete the committed account" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-committed@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    email = VisitorEmail.order(:created_at).last
    candidate = email
    delivery =
      enqueued_jobs.reverse.find do |entry|
        next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

        payload = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last.fetch(:params)
        payload.fetch(:public_id) == candidate.public_id
      end

    assert_not_nil delivery
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: payload.fetch(:sign_up_email_transaction_ref),
    )
    otp_data = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    assert_equal candidate.public_id, transaction.email_candidate_ref
    assert_equal transaction.otp_generation, payload.fetch(:sign_up_email_otp_generation)
    patch otp_url,
          params: { visitor_email: { pass_code: otp_data } }
    birthdate_url = response.location
    flow = VisitorSignUpFlow.order(:created_at).last
    version = flow.checkpoint_version
    patch birthdate_url, params: { requirement: "birthdate", checkpoint_version: version, birthdate: "1990-01-15" }

    assert_equal VisitorSignUpFlowStatus::COMPLETED, flow.reload.status_id

    patch birthdate_url, params: { requirement: "birthdate", checkpoint_version: version, birthdate: "1990-01-15" }

    assert_response :conflict
    assert_equal REFUSAL_BODY, response.body
    assert_equal VisitorSignUpFlowStatus::COMPLETED, flow.reload.status_id
    assert Visitor.exists?(id: flow.principal_id)
    assert VisitorEmail.exists?(id: email.id)

    post otp_url

    assert_response :conflict
    assert_equal VisitorSignUpFlowStatus::COMPLETED, flow.reload.status_id
    assert Visitor.exists?(id: flow.principal_id)
  end

  test "requests without a usable flow binding are refused and never halt the current flow" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-binding@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    flow = VisitorSignUpFlow.order(:created_at).last
    other_flow = VisitorSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(VisitorSignUpFlow),
      status_id: VisitorSignUpFlowStatus::CONTACT_PENDING, step: "contact", entry_method: "email",
      nonce_digest: VisitorSignUpFlow.digest_nonce("other-nonce"), issued_at: Time.current,
      expires_at: 10.minutes.from_now,
    )
    client_flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      status_id: ClientSignUpFlowStatus::CONTACT_PENDING, step: "contact", entry_method: "email",
      nonce_digest: ClientSignUpFlow.digest_nonce("client-nonce"), issued_at: Time.current,
      expires_at: 10.minutes.from_now,
    )
    bindings = {
      "missing" => nil,
      "empty" => "",
      "zero" => "0",
      "nul byte" => "a\u0000b",
      "malformed" => "not-a-signed-binding",
      "another flow" => SignFlowBindingCodec.encode(flow: other_flow, surface: :com),
      "another surface" => SignFlowBindingCodec.encode(flow: client_flow, surface: :app),
    }

    bindings.each do |label, binding|
      get auth_com_sign_up_check_email_otp_url({ ri: "jp", fb: binding }.compact)

      assert_response :conflict, "GET with #{label} binding"
      assert_equal REFUSAL_BODY, response.body

      patch auth_com_sign_up_check_email_otp_url({ ri: "jp", fb: binding }.compact),
            params: { visitor_email: { pass_code: "000000" } }

      assert_response :conflict, "PATCH with #{label} binding"
      assert_equal REFUSAL_BODY, response.body
      assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, flow.reload.status_id, "#{label} binding"
      assert_equal VisitorSignUpFlowStatus::CONTACT_PENDING, other_flow.reload.status_id, "#{label} binding"
    end
  end

  test "the otp phase is served one second before expiry and refused without a halt at and after expiry" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "phase-expiry@example.com", confirm_policy: "1" },
                   "cf-turnstile-response" => "test", }
    otp_url = response.location
    flow = VisitorSignUpFlow.order(:created_at).last
    flow.update!(expires_at: flow.class.database_now + 1.minute)

    travel_to flow.expires_at - 1.second, with_usec: true do
      get otp_url

      assert_response :success
    end

    [flow.expires_at, flow.expires_at + 1.second].each do |instant|
      travel_to instant, with_usec: true do
        get otp_url

        assert_not_equal 200, response.status, "GET at #{instant.iso8601}"
        assert_nil response.location

        post otp_url

        assert_not_equal 302, response.status, "POST at #{instant.iso8601}"
        assert_not_equal VisitorSignUpFlowStatus::HALTED, flow.reload.status_id
      end
    end
  end
end
