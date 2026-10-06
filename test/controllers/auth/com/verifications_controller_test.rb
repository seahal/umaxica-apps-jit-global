# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::VerificationsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "POST redeems the admission and the entry page lists the visitor's email and passkey methods only" do
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
    actor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    address = "com-entry-#{SecureRandom.hex(4)}@example.com"
    VisitorEmail.create!(
      visitor_id: actor.id, address: address, address_digest: IdentifierBlindIndex.bidx_for_email(address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED, otp_private_key: SecureRandom.base64(24),
      binding_finalized_at: VisitorEmail.database_now, otp_counter: "", otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    VisitorPasskey.create!(
      visitor: actor, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid, public_key: "public",
      description: "Entry passkey", sign_count: 0,
    )
    token = VisitorToken.create!(visitor: actor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_email", allowed_methods: %i(email_otp passkey),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:com", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/emails",
    )
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    get auth_com_verification_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]

    post auth_com_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_equal auth_com_verification_path(ri: "jp"), URI.parse(response.location).request_uri

    get auth_com_verification_path(ri: "jp")

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal %w(email_otp passkey), props.fetch("methods").map { |method| method.fetch("key") }.sort
    assert_equal auth_com_verification_cancellation_path(ri: "jp"), props.fetch("cancel").fetch("action")
    assert_equal "post", props.fetch("cancel").fetch("method")
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  # Sentinels of the reference parameter: missing, empty, unknown, NUL-bearing, and two references at once.
  test "the entry refuses a missing, empty, unknown or ambiguous admission reference without redirecting to sign-in" do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")

    get auth_com_verification_path(ri: "jp")

    assert_response :bad_request
    assert_nil response.headers["Location"]

    [
      {}, { entry_ref: "" }, { entry_ref: "unknown-reference" }, { entry_ref: "abc\u0000def" }, { entry_ref: "0" },
      { entry_ref: "a", transaction_ref: "b" },
    ].each do |params|
      post auth_com_verification_path(ri: "jp"), params: params

      assert_response :bad_request, params.inspect
      assert_equal I18n.t("errors.messages.invalid_request"), response.body
      assert_nil response.headers["Location"]
    end
    assert_equal 0, VisitorAuthCeremonySession.where.not(step_up_ceremony_transaction_ref: nil).count
  end

  test "an admission issued for the com surface is refused on the app host" do
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    actor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    token = VisitorToken.create!(visitor: actor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_email", allowed_methods: %i(email_otp passkey),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:com", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/emails",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }

    assert_response :bad_request
    assert_equal 0, ClientAuthCeremonySession.where.not(step_up_ceremony_transaction_ref: nil).count
    assert_equal "pending", issuance.transaction.reload.status
  end
end
