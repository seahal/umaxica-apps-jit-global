# frozen_string_literal: true

require "test_helper"

class StepUpCeremonyObservabilityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @original_logger = Rails.logger
    @log = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@log)
  end

  teardown do
    Rails.logger = @original_logger
  end

  test "admission, acceptance and cancellation of one ceremony share a keyed reference and log no identifier" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
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
    transaction_id = issuance.transaction.transaction_id

    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    get new_auth_app_verification_totp_path(ri: "jp")
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    post auth_app_verification_cancellation_path(ri: "jp"), params: { authenticity_token: form.fetch("csrf_token") }

    assert_response :see_other
    assert_equal "canceled", issuance.transaction.reload.status

    events = @log.string.lines.filter_map { |line| JSON.parse(line) if line.start_with?('{"event":"auth.step_up.') }
    accepted = events.find { |event| event.fetch("event") == "auth.step_up.ceremony_accepted" }.fetch("data")
    canceled = events.find { |event| event.fetch("event") == "auth.step_up.canceled" }.fetch("data")
    expected_reference = StepUpObservabilityDigest.ceremony_ref(transaction_id)

    assert_equal expected_reference, accepted.fetch("ceremony_ref")
    assert_equal expected_reference, canceled.fetch("ceremony_ref")
    assert_equal StepUpObservabilityDigest.session_ref(token.public_id), canceled.fetch("browser_session_digest")
    assert_equal "step_up", canceled.fetch("purpose")
    assert_equal "settings_birthdate", canceled.fetch("scope")
    assert_equal "pending", canceled.fetch("state_before")
    assert_equal "canceled", canceled.fetch("state_after")
    assert_predicate canceled.fetch("request_id"), :present?
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/, canceled.fetch("occurred_at"))

    step_up_log = events.to_json

    assert_not_includes step_up_log, transaction_id
    assert_not_includes step_up_log, token.public_id
    assert_not_includes step_up_log, issuance.reference
    assert_not_includes step_up_log, actor.public_id
    assert_not_includes step_up_log, csrf
  end

  test "an Auth ceremony page opened without admission is refused generically and logged as invalid_admission" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil response.headers["Location"]
    refusal = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
    }.sole.fetch("data")

    assert_equal "invalid_admission", refusal.fetch("error_code")
    assert_equal "auth_ceremony_context", refusal.fetch("stage")
    assert_equal "refused", refusal.fetch("outcome")
    assert_not refusal.key?("ceremony_ref")
    assert_not_includes response.body, "invalid_admission"
  end

  test "a second cancellation after the ceremony ended is refused and logged without changing the terminal state" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
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
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }
    get new_auth_app_verification_totp_path(ri: "jp")
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    post auth_app_verification_cancellation_path(ri: "jp"), params: { authenticity_token: form.fetch("csrf_token") }
    canceled_at = issuance.transaction.reload.canceled_at

    post auth_app_verification_cancellation_path(ri: "jp"), params: { authenticity_token: form.fetch("csrf_token") }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_equal "canceled", issuance.transaction.reload.status
    assert_equal canceled_at, issuance.transaction.canceled_at
    refusals =
      @log.string.lines.filter_map { |line|
        JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
      }

    assert_equal ["invalid_admission"], refusals.map { |event| event.fetch("data").fetch("error_code") }
  end

  test "reading an expired ceremony is refused without rewriting its stored status" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
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
    # Moves the deadline into the past; no public API shortens a live transaction.
    issuance.transaction.update_columns(expires_at: ClientStepUpCeremonyTransaction.database_now - 1.second)
    updated_at = issuance.transaction.reload.updated_at

    [auth_app_verification_path(ri: "jp"), new_auth_app_verification_totp_path(ri: "jp"),
     auth_app_verification_handoff_path(ri: "jp"),].each do |path|
      get path

      assert_response :bad_request, path
      assert_equal I18n.t("errors.messages.invalid_request"), response.body
    end
    issuance.transaction.reload

    assert_equal "pending", issuance.transaction.status
    assert_equal updated_at, issuance.transaction.updated_at
    refusals =
      @log.string.lines.filter_map { |line|
        JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
      }

    assert_equal ["transaction_expired"] * 3, refusals.map { |event| event.fetch("data").fetch("error_code") }
    assert_equal [StepUpObservabilityDigest.ceremony_ref(issuance.transaction.transaction_id)] * 3,
                 refusals.map { |event| event.fetch("data").fetch("ceremony_ref") }
  end

  test "an unauthenticated Base page request records which credentials the browser presented" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_identity_path(ri: "jp"), headers: { "Sec-Fetch-Site" => "cross-site" }

    assert_response :redirect
    required = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.session.authentication_required"')
    }.sole.fetch("data")

    assert_equal "Base::App::IdentitiesController", required.fetch("controller")
    assert_equal "blank_access_token", required.fetch("failure_reason")
    assert_not required.fetch("access_credential_presented")
    assert_not required.fetch("refresh_credential_presented")
    assert_equal "cross-site", required.fetch("fetch_site")
    assert_predicate required.fetch("occurred_at"), :present?
  end

  # Sentinels of the header: empty, and a value outside the fetch-metadata vocabulary. An absent
  # header is not reachable here: the integration client supplies "same-origin" when none is given.
  test "the authentication-required record omits an empty or unknown fetch-site value" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    [{ "Sec-Fetch-Site" => "" }, { "Sec-Fetch-Site" => "https://evil.example/\u0000" }].each do |headers|
      get base_app_identity_path(ri: "jp"), headers: headers

      assert_response :redirect
    end
    records =
      @log.string.lines.filter_map { |line|
        JSON.parse(line) if line.start_with?('{"event":"auth.session.authentication_required"')
      }

    assert_equal [nil, nil], records.map { |record| record.fetch("data")["fetch_site"] }
    assert_not_includes @log.string, "evil.example"
  end

  test "a Base completion without the browser transaction marker is refused as return_binding_mismatch" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(
      user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB, user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    access_token = AuthenticationToken.encode(
      actor, host: host, session_public_id: token.public_id, resource_type: "client",
             jwt_issuer_id: "surface:BASE_APP",
    )

    host! host
    post base_app_verification_completion_path(ri: "jp"),
         params: { transaction_ref: "5f0c1b1e-0000-4000-8000-000000000001", result: "opaque-result" },
         headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    refusal = @log.string.lines.filter_map { |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
    }.sole.fetch("data")

    assert_equal "return_binding_mismatch", refusal.fetch("error_code")
    assert_equal "base_completion", refusal.fetch("stage")
    assert_equal StepUpObservabilityDigest.session_ref(token.public_id), refusal.fetch("browser_session_digest")
    assert_not_includes @log.string.lines.grep(/auth\.step_up\./).join, "opaque-result"
    assert_not_includes @log.string.lines.grep(/auth\.step_up\./).join, access_token
    assert_nil token.reload.last_step_up_at
  end
end
