# frozen_string_literal: true

require "test_helper"

class Auth::Org::VerificationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens, :operator_passkeys

  test "POST redeems the admission and the entry page offers the operator's passkey only" do
    actor = operators(:one)
    token = operator_tokens(:one)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:org", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/emails",
    )
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    get auth_org_verification_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]

    post auth_org_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_equal auth_org_verification_path(ri: "jp"), URI.parse(response.location).request_uri

    get auth_org_verification_path(ri: "jp")

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal(
      [{ "key" => "passkey",
         "label" => I18n.t("sign.org.verification.new.methods.passkey"),
         "href" => new_auth_org_verification_passkey_path(ri: "jp"), }],
      props.fetch("methods"),
    )
    assert_equal auth_org_verification_cancellation_path(ri: "jp"), props.fetch("cancel").fetch("action")
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  # Sentinels of the reference parameter: missing, empty, unknown, NUL-bearing, and two references at once.
  test "the entry refuses a missing, empty, unknown or ambiguous admission reference without redirecting to sign-in" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    get auth_org_verification_path(ri: "jp")

    assert_response :bad_request
    assert_nil response.headers["Location"]

    [
      {}, { entry_ref: "" }, { entry_ref: "unknown-reference" }, { entry_ref: "abc\u0000def" }, { entry_ref: "0" },
      { entry_ref: "a", transaction_ref: "b" },
    ].each do |params|
      post auth_org_verification_path(ri: "jp"), params: params

      assert_response :bad_request, params.inspect
      assert_equal I18n.t("errors.messages.invalid_request"), response.body
      assert_nil response.headers["Location"]
    end
    assert_equal 0, OperatorAuthCeremonySession.where.not(step_up_ceremony_transaction_ref: nil).count
  end

  test "an admission issued for the org surface is refused on the app host" do
    actor = operators(:one)
    token = operator_tokens(:one)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:org", session_binding: token.public_id, token_binding: token.public_id,
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
