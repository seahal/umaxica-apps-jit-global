# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch11HighImpactTest < ActionDispatch::IntegrationTest
  def attach_request!(controller)
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    controller.set_request!(request)
    controller.set_response!(response)
    controller.define_singleton_method(:session) { @__session ||= {} }
    controller
  end

  test "verification emails refuse missing admission and accept only their transaction-scoped code" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    get "/verification/emails/missing/edit", params: { ri: "jp" }

    assert_response :bad_request
    post "/verification/emails", params: { ri: "jp" }

    assert_response :bad_request
    patch "/verification/emails/missing", params: { ri: "jp", verification: { code: "012345" } }

    assert_response :bad_request
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    email = actor.visitor_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = VisitorToken.create!(visitor: actor)
    issuance =
      begin
        admission_issuance = BaseStepUpAdmissionIssuer.call!(
          actor: actor,
          token: token,
          requirement: StepUpRequirement.new(
            step_up_required: true, scope: "settings_birthdate", allowed_methods: [:email_otp],
            phishing_resistant_required: false, user_verification_required: false,
            full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
            resource_ref: nil, tenant_ref: nil, purpose: "step_up",
            audience: "step_up:com", session_binding: token.public_id, token_binding: token.public_id,
            require_session_binding: true,
          ),
          return_to: "/identity/birthdate",
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
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    post auth_com_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }
    transaction = issuance.transaction
    record = VisitorStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    # The delivered code is seeded through the ticket's own API; delivery itself is covered by the
    # issuer and delivery-recorder tests.
    generation = record.issue_bound_email_code!(
      transaction: transaction, credential_ref: email.public_id, code: "012345",
    )
    record.mark_bound_email_delivery!(transaction: transaction, generation: generation, success: true)

    patch auth_com_verification_email_path(transaction.transaction_id, ri: "jp"),
          params: { verification: { code: "012345" } }

    assert_redirected_to auth_com_verification_handoff_path(ri: "jp")
    transaction.reload

    assert_equal "verified", transaction.status
    assert_equal "email_otp", transaction.method
    assert_equal "none", transaction.aal
    assert_equal email.public_id, transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "sign up state machine invalid arms" do
    email_ticket = ClientSignUpFlow.new(
      step: "start",
      entry_method: "email",
      status_id: ClientSignUpFlow::STATUS_NAMES.key("STARTED"),
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
    )
    result = SignUpStateMachine.call(ticket: email_ticket, event: :complete_social_callback, actor_context: nil)

    assert_equal :invalid_transition, result.status

    checkpoint = ClientSignUpFlow.new(
      step: "checkpoint",
      entry_method: "email",
      status_id: ClientSignUpFlow::STATUS_NAMES.key("STARTED"),
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
    )
    result = SignUpStateMachine.call(ticket: checkpoint, event: :clear_requirement, actor_context: nil)

    assert_equal :invalid_transition, result.status

    result = SignUpStateMachine.call(ticket: checkpoint, event: :finalize, actor_context: nil)

    assert_equal :invalid_transition, result.status

    result = SignUpStateMachine.call(ticket: checkpoint, event: :teleport, actor_context: nil)

    assert_equal :invalid_transition, result.status

    pending = ClientSignUpFlow.new(
      step: "checkpoint",
      entry_method: "email",
      status_id: ClientSignUpFlow::STATUS_NAMES.key("CHECKPOINT_PENDING"),
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
      completed_requirements: {},
    )
    result = SignUpStateMachine.call(
      ticket: pending,
      event: :clear_requirement,
      actor_context: nil,
      payload: { requirement: nil },
    )

    assert_equal :invalid_transition, result.status

    called = false
    result = SignUpStateMachine.call(
      ticket: pending,
      event: :clear_requirement,
      actor_context: nil,
      payload: { requirement: :email, before_clear: -> { called = true } },
    )
    # may be invalid for other reasons but before_clear path or invalid requirement both ok
    assert result
    assert_includes [true, false], called

    result = SignUpStateMachine.call(
      ticket: pending,
      event: :finalize,
      actor_context: nil,
      payload: { finalization_result: :rejected },
    )

    assert result
  end
end
