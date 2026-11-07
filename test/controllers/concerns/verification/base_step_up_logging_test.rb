# typed: false
# frozen_string_literal: true

require "test_helper"

class VerificationBaseStepUpLoggingTest < ActionDispatch::IntegrationTest
  test "an unavailable RP contact mutation logs its refusal without changing credentials" do
    https!
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    actor = clients(:one)
    headers = as_user_headers(actor, host: host)
    token = ClientToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_credential_ref: SecureRandom.uuid,
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    contact = actor.client_emails.create!(
      address: "log-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    logs = []
    Rails.logger.stub(:info, ->(message = nil, &block) { logs << (message || block.call) }) do
      delete base_app_identity_email_path(contact.public_id, ri: "jp"), headers: headers
    end

    assert_response :service_unavailable
    assert_not_predicate contact.reload, :binding_released?
    event =
      logs.filter_map { |entry| JSON.parse(entry, symbolize_names: true) if entry.start_with?("{") }
        .find { |entry| entry[:event] == "auth.rp_feature.refused" }

    assert event, "expected the refusal log for the unavailable RP feature"
    data = event.fetch(:data)

    assert_equal "rp_root_session_unavailable", data[:reason_code]
    assert_equal "contact_mutation", data[:feature]
    assert_equal "base_app", data[:surface]
    serialized = event.to_json

    [token.public_id, actor.public_id, headers.fetch("Cookie")].each do |private_value|
      assert_not_includes serialized, private_value
    end
  end
end
