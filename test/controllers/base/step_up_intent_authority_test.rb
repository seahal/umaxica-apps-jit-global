# frozen_string_literal: true

require "test_helper"
require_relative "../../support/rp_cell_session_helper"

# Ordinary Base step-up is RP-local and starts the OIDC authorization request. The legacy ticket
# authority is retained only for bootstrap, registration and full reauthentication.
class BaseStepUpIntentAuthorityTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.fixture_table_names = []

  test "APP ordinary verification starts on the RP session without creating a Base ticket" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    ClientPasskey.create!(
      user: actor,
      webauthn_id: SecureRandom.uuid,
      external_id: SecureRandom.uuid,
      public_key: "step-up-intent-authority-passkey",
      sign_count: 0,
      description: "Step-up intent test passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    root_token = authentication_harness_create_token(actor)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! base_host
    https!

    as_rp_cell("base-app-ww") do
      _token_response, _payload, rp_session = sign_in_rp_cell("base-app-ww", actor:, root_token:)
      tickets_before = ClientStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count

      get base_app_verification_path(ri: "jp")

      assert_response :success
      assert_equal tickets_before, ClientStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count

      post base_app_verification_path(ri: "jp"),
           params: { return_target: "/settings/birthdate" },
           headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }

      assert_response :see_other
      state = RpStepUpState.find_by!(rp_session:)
      outbox = RpStepUpAuditOutbox.find_by!(context_ref: state.public_id)

      assert_equal RpStepUpStateStatus::PENDING, state.state_id
      assert_equal "step_up.requested", outbox.event_type
      assert_equal "/settings/birthdate", state.return_target
      assert_equal tickets_before, ClientStepUpCeremonyTransaction.where(actor_ref: actor.public_id).count
    end
  end
end
