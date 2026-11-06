# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/rp_cell_session_helper"

# Email-preference update on the app identity surface, including its Turnstile
# rejection branch.
class BaseIdentitySessionsAndEmailPreferencesTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  fixtures :clients, :client_statuses, :client_email_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses

  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app email preference update saves the new notification setting" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    email = ClientEmail.create!(
      user: client, address: "app_email_preference@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED, notifiable: false,
    )
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.rotate_refresh_token! unless token.device_session.current_refresh_token_id
    sign_in_rp_cell_with_step_up_evidence("base-app-ww", actor: client, root_token: token)

    assert_nil token.reload.last_step_up_at

    assert_nil token.reload.last_step_up_at
    assert_equal token.id, token.device_session.current_refresh_token_id
    unexpected_commit = ->(**) { flunk("RP contact mutation reached the retired OP-root writer") }
    IdentityEmailPreferenceCommitter.stub(:call!, unexpected_commit) do
      patch base_app_identity_email_url(email.public_id, ri: "jp", host: host),
            params: { user_email: { notifiable: "1" } },
            headers: { "Host" => host }

      assert_response :service_unavailable
      assert_not email.reload.notifiable?
      assert_nil token.reload.last_step_up_at
    end

    patch base_app_identity_email_url(email.public_id, ri: "jp", host: host),
          params: { user_email: { notifiable: "1" } }, headers: { "Host" => host }

    assert_response :service_unavailable
    assert_not email.reload.notifiable?
  end

  test "unavailable RP contact mutation stays closed when the stealth Turnstile check fails" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    email = ClientEmail.create!(
      user: client, address: "app_email_preference_turnstile@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED, notifiable: false,
    )
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.rotate_refresh_token! unless token.device_session.current_refresh_token_id
    sign_in_rp_cell_with_step_up_evidence("base-app-ww", actor: client, root_token: token)

    assert_nil token.reload.last_step_up_at
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_nil token.reload.last_step_up_at
    assert_equal token.id, token.device_session.current_refresh_token_id
    patch base_app_identity_email_url(email.public_id, ri: "jp", host: host),
          params: { user_email: { notifiable: "1" } },
          headers: { "Host" => host }

    assert_response :service_unavailable
    assert_not email.reload.notifiable?
  end
end
