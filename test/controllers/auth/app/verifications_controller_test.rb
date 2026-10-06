# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::VerificationsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :client_statuses

  test "GET with a Base admission reference shows a continuation and consumes nothing" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: %i(email_otp totp passkey),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    2.times do
      get auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)

      assert_response :success
      form = response.parsed_body.at_css("form#auth-admission-continuation-form")

      assert_equal "post", form["method"]
      assert_equal auth_app_verification_path, URI.parse(form["action"]).path
      assert_equal issuance.reference, form.at_css('input[name="entry_ref"]')["value"]
      assert_equal "private, no-store", response.headers["Cache-Control"]
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
    end
    assert_equal "pending", issuance.transaction.reload.status
    assert_equal 0, ClientAuthCeremonySession.where(
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    ).count
  end

  test "POST redeems the admission once and the clean entry page lists only the actor's usable methods" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    email = ClientEmail.create!(
      user: actor, address: "verification-entry-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, otp_private_key: "otp_private_key", otp_counter: "0",
    )
    email.finalize_binding!
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: %i(email_otp totp passkey),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]

    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_equal auth_app_verification_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_not_includes response.location, issuance.reference

    get auth_app_verification_path(ri: "jp")

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal(
      [{ "key" => "email_otp",
         "label" => I18n.t("sign.app.verification.new.methods.email_otp"),
         "href" => new_auth_app_verification_email_path(ri: "jp"), }],
      props.fetch("methods"),
    )
    assert_nil props.fetch("no_methods_notice")
    assert_equal(
      { "label" => I18n.t("actions.cancel"),
        "action" => auth_app_verification_cancellation_path(ri: "jp"),
        "method" => "post", },
      props.fetch("cancel"),
    )
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "an admission reference cannot be redeemed twice" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: %i(email_otp totp passkey),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }

    assert_response :see_other

    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }

    assert_response :see_other
    assert_equal auth_app_verification_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_equal 1, ClientAuthCeremonySession.where(
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    ).count
  end

  # Sentinels of the reference parameter: missing, empty, unknown, NUL-bearing, and two references at once.
  test "the entry refuses a missing, empty, unknown or ambiguous admission reference without redirecting to sign-in" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get auth_app_verification_path(ri: "jp")

    assert_response :bad_request
    assert_nil response.headers["Location"]

    [
      {}, { entry_ref: "" }, { entry_ref: "unknown-reference" }, { entry_ref: "abc\u0000def" }, { entry_ref: "0" },
      { entry_ref: "a", transaction_ref: "b" },
    ].each do |params|
      post auth_app_verification_path(ri: "jp"), params: params

      assert_response :bad_request, params.inspect
      assert_equal I18n.t("errors.messages.invalid_request"), response.body
      assert_nil response.headers["Location"]
    end
    assert_equal 0, ClientAuthCeremonySession.where.not(step_up_ceremony_transaction_ref: nil).count
  end

  test "a bootstrap admission is not accepted by the verification entry and stays redeemable for setup" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, allowed_methods: %i(passkey totp),
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, ttl: 15.minutes,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }

    assert_response :bad_request
    assert_equal "pending", issuance.transaction.reload.status

    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference }

    assert_response :see_other
    assert_equal new_auth_app_verification_setup_path(ri: "jp"), URI.parse(response.location).request_uri
  end

  test "an admission issued for the app surface is refused on the com host" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: %i(email_otp totp passkey),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")

    post auth_com_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }

    assert_response :bad_request
    assert_equal 0, VisitorAuthCeremonySession.where.not(step_up_ceremony_transaction_ref: nil).count
    assert_equal "pending", issuance.transaction.reload.status
  end

  test "the entry page is refused once the Base session behind the ceremony is revoked" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: %i(email_otp totp passkey),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }
    token.revoke!

    get auth_app_verification_path(ri: "jp")

    assert_response :bad_request
    assert_nil response.headers["Location"]
    assert_equal "revoked", issuance.transaction.reload.status
  end
end
