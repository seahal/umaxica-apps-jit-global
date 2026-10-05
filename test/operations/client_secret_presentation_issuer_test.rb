# frozen_string_literal: true

require "test_helper"

class ClientSecretPresentationIssuerTest < ActiveSupport::TestCase
  test "manual presentation generates exactly the reserved set once and storage declaration activates it" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, established_authentication_method: "secret")
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    assert_difference("ClientSecretCredential.count", 1) do
      ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
      values = ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance)

      assert_equal 1, values.length
      assert_match ClientSecretCredential::SECRET_FORMAT, values.first
      assert_nil ClientSecretLookupQuery.call(secret: values.first)
      assert_nil issuance.reload.encrypted_payload
      assert_no_difference("ClientSecretCredential.count") do
        assert_raises(ClientSecretPresentationIssuer::AlreadyPresented) do
          ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance)
        end
      end
      ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)

      assert_equal issuance.id, ClientSecretLookupQuery.call(secret: values.first).issuance_id
    end
  end

  test "unscoped or different browser cannot generate or present candidates" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    other = ClientToken.create!(user: actor)
    [other, token].each do |browser|
      token.update!(last_step_up_at: nil) if browser == token
      assert_no_difference("ClientSecretCredential.count") do
        assert_raises(ClientSecretPresentationIssuer::Denied) do
          ClientSecretPresentationIssuer.call!(actor_context: context, token: browser, issuance: issuance)
        end
      end
    end
    assert_nil issuance.reload.presented_at
  end
end
