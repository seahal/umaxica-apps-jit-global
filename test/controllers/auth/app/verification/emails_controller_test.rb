# typed: false
# frozen_string_literal: true

require "test_helper"

# Admission, read-only GET and code issuance are covered by AuthStepUpAdmissionTest; these cases
# cover code submission over HTTP and method admission.
class Auth::App::Verification::EmailsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :client_statuses

  test "the delivered code records email evidence and hands off without granting freshness" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = ClientToken.create!(user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:email_otp], purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }
    transaction = issuance.transaction
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    # The delivered code is seeded through the ticket's own API; delivery itself is covered by the
    # issuer and delivery-recorder tests.
    generation = record.issue_bound_email_code!(
      transaction: transaction, credential_ref: email.public_id, code: "012345",
    )
    record.mark_bound_email_delivery!(transaction: transaction, generation: generation, success: true)

    patch auth_app_verification_email_path(transaction.transaction_id, ri: "jp"),
          params: { verification: { code: "012345" } }

    assert_redirected_to auth_app_verification_handoff_path(ri: "jp")
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
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = ClientToken.create!(user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:email_otp], purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }
    transaction = issuance.transaction
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
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
      patch auth_app_verification_email_path(transaction.transaction_id, ri: "jp"), params: params

      assert_response :unprocessable_content, params.inspect
      assert_equal "pending", transaction.reload.status, params.inspect
    end
    assert_nil transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
  end

  test "the email endpoints are refused when Base did not admit email for the ceremony" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = ClientToken.create!(user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:totp], purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }
    transaction = issuance.transaction

    get new_auth_app_verification_email_path(ri: "jp")

    assert_response :bad_request
    post auth_app_verification_emails_path(ri: "jp")

    assert_response :bad_request
    get edit_auth_app_verification_email_path(transaction.transaction_id, ri: "jp")

    assert_response :bad_request
    patch auth_app_verification_email_path(transaction.transaction_id, ri: "jp"),
          params: { verification: { code: "012345" } }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_equal "pending", transaction.reload.status
    assert_equal 0, email.reload.step_up_otp_failures
  end
end
