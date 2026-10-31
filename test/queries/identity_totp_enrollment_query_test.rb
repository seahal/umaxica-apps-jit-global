# frozen_string_literal: true

require "test_helper"

class IdentityTotpEnrollmentQueryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "only the current usable device can read the enrollment candidate" do
    %i(revoked superseded).each do |invalidation|
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      transaction = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
        required_scope: "settings_totp", step_up_required: false, allowed_methods: ["totp"],
      )
      ClientStepUpSession.create!(
        user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
        step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
      )
      candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)

      displayed = IdentityTotpEnrollmentQuery.call(actor: actor, token: token, transaction: transaction)

      assert_equal candidate.id, displayed.id
      device = token.device_session_record!
      if invalidation == :revoked
        device.revoke!
      else
        replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
        device.update!(current_refresh_token_id: replacement.id)
      end

      assert_raises(IdentityTotpCeremonyContract::Error) do
        IdentityTotpEnrollmentQuery.call(actor: actor, token: token, transaction: transaction)
      end
      assert_nil candidate.reload.last_otp_at
      assert_equal "pending", transaction.reload.status
    end
  end
end
