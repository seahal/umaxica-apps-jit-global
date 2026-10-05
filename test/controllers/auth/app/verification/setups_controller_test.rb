# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :client_statuses

  test "an admitted bootstrap shows the registration methods and cancellation, never a back link" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_telephone", purpose: "bootstrap", step_up_required: false,
        allowed_methods: %i(passkey totp), audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true, ttl: 15.minutes,
      ), return_to: "/identity/telephones",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_equal new_auth_app_verification_setup_path(ri: "jp"), URI.parse(response.location).request_uri

    get new_auth_app_verification_setup_path(ri: "jp")

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    methods = props.fetch("methods").to_h { |method| [method.fetch("key"), method.fetch("href")] }

    assert_equal %w(email passkey totp), methods.keys.sort
    assert_equal new_auth_app_settings_passkey_path(ri: "jp"), methods.fetch("passkey")
    assert_equal new_auth_app_settings_totp_path(ri: "jp"), methods.fetch("totp")
    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), URI.parse(methods.fetch("email")).host
    assert_equal "/identity/emails/registration/new", URI.parse(methods.fetch("email")).path
    assert_not props.key?("back")
    assert_equal(
      { "label" => I18n.t("actions.cancel"),
        "action" => auth_app_verification_cancellation_path(ri: "jp"),
        "method" => "post", },
      props.fetch("cancel"),
    )
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  test "the setup page is refused without an admitted bootstrap and never redirects to sign-in" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get new_auth_app_verification_setup_path(ri: "jp")

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil response.headers["Location"]
  end

  test "a step-up admission is not accepted by the setup entry" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: %i(email_otp totp passkey), purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference }

    assert_response :bad_request
    assert_equal 0, ClientAuthCeremonySession.where(
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    ).count
  end

  # Pins a confirmed defect: Passkey registration still runs on the retired Auth login contract,
  # so its setup link leaves the admitted ceremony for Base sign-in. This test changes when Passkey
  # registration becomes an admission-only ceremony.
  test "the passkey registration link currently leaves the admitted bootstrap for Base sign-in through Jump" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_telephone", purpose: "bootstrap", step_up_required: false,
        allowed_methods: %i(passkey totp), audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true, ttl: 15.minutes,
      ), return_to: "/identity/telephones",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference }

    get new_auth_app_settings_passkey_path(ri: "jp")

    assert_response :found
    jump = URI.parse(response.location)

    assert_equal "jump.umaxica.net", jump.host
    target, = JWT.decode(Rack::Utils.parse_nested_query(jump.query).fetch("rt"), nil, false)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), URI.parse(target.fetch("url")).host
    assert_equal "/sign", URI.parse(target.fetch("url")).path
    assert_equal "pending", issuance.transaction.reload.status
  end
end
