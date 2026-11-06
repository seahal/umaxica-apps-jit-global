# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class StepUpCeremonyObservabilityTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.fixture_table_names = []

  setup do
    @original_logger = Rails.logger
    @log = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@log)
  end

  teardown do
    Rails.logger = @original_logger
  end

  test "RP step-up start logs a keyed reference without state, actor or session identifiers" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    ClientPasskey.create!(
      user: actor, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid,
      public_key: "step-up-observability-passkey", sign_count: 0,
      description: "Step-up observability test passkey", status_id: ClientPasskeyStatus::ACTIVE,
    )
    root_token = authentication_harness_create_token(actor)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! base_host
    https!

    as_rp_cell("base-app-ww") do
      _token_response, _payload, rp_session = sign_in_rp_cell("base-app-ww", actor:, root_token:)

      post base_app_verification_path(ri: "jp"),
           params: { return_target: "/settings/birthdate" },
           headers: {
             "Origin" => "https://#{base_host}",
             "Sec-Fetch-Site" => "same-origin",
           }

      assert_response :see_other
      state = RpStepUpState.find_by!(rp_session:)
      events = @log.string.lines.filter_map do |line|
        parsed = JSON.parse(line) if line.start_with?('{"event":"auth.step_up.')
        parsed if parsed
      end.sole
      event = events.fetch("data")

      assert_equal "auth.step_up.admission_issued", events.fetch("event")
      assert_equal StepUpObservabilityDigest.ceremony_ref(state.public_id), event.fetch("ceremony_ref")
      assert_equal "issued", event.fetch("outcome")
      assert_equal "pending", event.fetch("state_after")
      logged_events = events.to_json

      assert_not_includes logged_events, state.public_id
      assert_not_includes logged_events, actor.public_id
      assert_not_includes logged_events, rp_session.public_id
      assert_not_includes logged_events, root_token.public_id
    end
  end

  test "an Auth ceremony page opened without an OIDC step-up context is refused generically and logged" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil response.headers["Location"]
    refusal = @log.string.lines.filter_map do |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
    end.sole.fetch("data")

    assert_equal "invalid_admission", refusal.fetch("error_code")
    assert_equal "auth_ceremony_context", refusal.fetch("stage")
    assert_equal "refused", refusal.fetch("outcome")
    assert_not refusal.key?("ceremony_ref")
    assert_not_includes response.body, "invalid_admission"
  end
end
