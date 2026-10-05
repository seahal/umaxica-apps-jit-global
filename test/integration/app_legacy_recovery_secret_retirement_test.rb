# frozen_string_literal: true

require "test_helper"

class AppLegacyRecoverySecretRetirementTest < ActionDispatch::IntegrationTest
  test "retired app recovery reveal has no anonymous GET HEAD or OPTIONS entry" do
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))

    get "/identity/recovery-secret?ri=jp", env: { "action_dispatch.show_exceptions" => :all }

    assert_response :not_found

    head "/identity/recovery-secret?ri=jp", env: { "action_dispatch.show_exceptions" => :all }

    assert_response :not_found
    assert_empty response.body

    options "/identity/recovery-secret?ri=jp", env: { "action_dispatch.show_exceptions" => :all }

    assert_response :not_found
  end

  test "an existing app reveal receipt cannot be consumed through the retired URL" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)
    actor = clients(:one)
    headers = as_user_headers(actor, host: host)
    reveal = IdentityOneTimeReveal.issue!(
      actor: actor, session_nonce: actor.public_id,
      value: ["synthetic-retired-recovery-value"], purpose: "client.recovery_secret_credential",
    )
    receipt = SecurityOneTimeReveal.find_by!(
      actor_type: "Client", actor_id: actor.id, purpose: "client.recovery_secret_credential",
      consumed_at: nil,
    )

    get(
      "/identity/recovery-secret",
      params: { ri: "jp", token: reveal.token }, headers: headers,
      env: { "action_dispatch.show_exceptions" => :all },
    )

    assert_response :not_found
    assert_not_includes response.body, "synthetic-retired-recovery-value"
    assert_nil receipt.reload.consumed_at
    assert_not_nil receipt.encrypted_payload
  end
end
