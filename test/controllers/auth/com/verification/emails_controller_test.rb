# typed: false
# frozen_string_literal: true

require "test_helper"

# Admission, read-only GET and code issuance are covered by AuthStepUpAdmissionTest; these cases
# cover code submission over HTTP and method admission.
class Auth::Com::Verification::EmailsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :visitor_statuses

  test "the delivered code records email evidence and hands off without granting freshness" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    email = actor.visitor_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = VisitorToken.create!(visitor: actor)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:email_otp],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:com", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
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

  # Partitions of the submitted code: a wrong six-digit code, and codes that are not six digits
  # (missing, empty, zero, five digits, seven digits, NUL-bearing).
  test "a wrong or malformed code re-renders the entry page and keeps the ceremony pending" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    email = actor.visitor_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = VisitorToken.create!(visitor: actor)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:email_otp],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:com", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
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

    [
      { verification: { code: "999999" } }, {}, { verification: { code: "" } }, { verification: { code: "0" } },
      { verification: { code: "01234" } }, { verification: { code: "0123456" } },
      { verification: { code: "0123\u00005" } },
    ].each do |params|
      patch auth_com_verification_email_path(transaction.transaction_id, ri: "jp"), params: params

      assert_response :unprocessable_content, params.inspect
      assert_equal "pending", transaction.reload.status, params.inspect
    end
    assert_nil transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
  end

  test "the email endpoints are refused when Base did not admit email for the ceremony" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    email = actor.visitor_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = VisitorToken.create!(visitor: actor)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:com", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    post auth_com_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }
    transaction = issuance.transaction

    get new_auth_com_verification_email_path(ri: "jp")

    assert_response :bad_request
    post auth_com_verification_emails_path(ri: "jp")

    assert_response :bad_request
    get edit_auth_com_verification_email_path(transaction.transaction_id, ri: "jp")

    assert_response :bad_request
    patch auth_com_verification_email_path(transaction.transaction_id, ri: "jp"),
          params: { verification: { code: "012345" } }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_equal "pending", transaction.reload.status
    assert_equal 0, email.reload.step_up_otp_failures
  end

  test "a second code is not issued inside the resend interval and the first code stays valid" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    email = actor.visitor_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = VisitorToken.create!(visitor: actor)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:email_otp],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:com", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    post auth_com_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }
    record = VisitorStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    post auth_com_verification_emails_path(ri: "jp")

    assert_redirected_to edit_auth_com_verification_email_path(issuance.transaction.transaction_id, ri: "jp")
    assert_equal 1, record.reload.email_code_generation
    first_digest = record.email_code_digest

    post auth_com_verification_emails_path(ri: "jp")

    assert_response :unprocessable_content
    assert_equal 1, record.reload.email_code_generation
    assert_equal first_digest, record.email_code_digest
    assert_equal email.public_id, record.email_credential_ref
  end
end
