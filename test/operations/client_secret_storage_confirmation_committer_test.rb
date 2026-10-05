# frozen_string_literal: true

require "test_helper"

class ClientSecretStorageConfirmationCommitterTest < ActiveSupport::TestCase
  test "storage declaration activates the presented manual reservation and preserves the session" do
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
    raw = SecureRandom.base58(32)
    candidate = ClientSecretCredential.create!(
      client: actor, issuance: issuance, name: "Stored value", password: raw,
      lookup_digest: SignSecretLookupDigest.digest(raw),
    )
    # Prepare completed presentation facts; this test does not deliver plaintext.
    ClientSecretIssuance.transaction do
      at = Client.database_now
      issuance.update!(presented_at: at)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
        operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
      )
    end
    original_token = token.attributes

    assert_difference("ClientSecretAuditOutbox.count", 2) do
      ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
    end

    assert_equal :confirmed, issuance.reload.state(at: Client.database_now)
    assert_equal issuance.confirmed_at, candidate.reload.confirmed_at
    assert_equal candidate.id, ClientSecretLookupQuery.call(secret: raw).id
    counts = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 1, counts.active_count
    assert_equal 0, counts.reserved_count
    assert_equal original_token, token.reload.attributes
    confirmed_at = issuance.confirmed_at
    assert_no_difference("ClientSecretAuditOutbox.count") do
      ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
    end
    assert_equal confirmed_at, issuance.reload.confirmed_at

    assert_raises(ActiveRecord::ReadonlyAttributeError) { candidate.update!(confirmed_at: nil) }
    assert_raises(ActiveRecord::ActiveRecordError) { candidate.update_columns(confirmed_at: nil) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { candidate.write_attribute(:confirmed_at, nil) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { candidate.touch(:confirmed_at) }
    [nil, confirmed_at - Rational(1, 1_000_000), confirmed_at + Rational(1, 1_000_000)].each do |replacement|
      assert_raises(ActiveRecord::ReadonlyAttributeError) { candidate.reload[:confirmed_at] = replacement }
      assert_equal confirmed_at, candidate.reload.confirmed_at
    end
  end

  test "the exact two presented candidates confirm together and source audit failure rolls back the whole batch" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_passkey",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    at = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: actor, origin_operation_id: SecureRandom.uuid, origin: "passkey_registration", attempt_number: 1,
      planned_count: 2, browser_session_ref: token.public_id, expires_at: at + 1.minute, presented_at: at,
    )
    # Prepare presentation evidence; registration and plaintext delivery are outside this boundary.
    candidates =
      2.times.map do |index|
        raw = SecureRandom.base58(32)
        ClientSecretCredential.create!(
          client: actor, issuance: issuance, name: "Batch item #{index}", password: raw,
          lookup_digest: SignSecretLookupDigest.digest(raw),
        )
      end
    ClientSecretAuditOutbox.transaction do
      candidates.each do |candidate|
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
          operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
        )
      end
    end
    ids = [SecureRandom.uuid, SecureRandom.uuid, "invalid-event-id"]
    assert_no_difference("ClientSecretAuditOutbox.count") do
      SecureRandom.stub(:uuid, -> { ids.shift }) do
        assert_raises(ActiveRecord::RecordInvalid) do
          ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
        end
      end
    end
    assert_nil issuance.reload.confirmed_at
    candidates.each { |candidate| assert_nil candidate.reload.confirmed_at }
    counts = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 0, counts.active_count
    assert_equal 2, counts.reserved_count
    assert_difference("ClientSecretAuditOutbox.count", 3) do
      ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
    end
    candidates.each { |candidate| assert_equal issuance.reload.confirmed_at, candidate.reload.confirmed_at }
    counts = ClientSecretCapacityQuery.call(client: actor, at: Client.database_now)

    assert_equal 2, counts.active_count
    assert_equal 0, counts.reserved_count
  end

  test "confirmation refuses invalid authority and inconsistent presentation evidence" do
    %i(no_step_up wrong_scope wrong_session wrong_owner expired_step_up revoked restricted
       secret_method unpresented unaudited mismatched_presented extra_candidate).each do |scenario|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor)
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
        last_step_up_method: "totp", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      )
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
      issuance = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      )
      raw = SecureRandom.base58(32)
      candidate = ClientSecretCredential.create!(
        client: actor, issuance: issuance, name: "Pending value", password: raw,
        lookup_digest: SignSecretLookupDigest.digest(raw),
      )
      ClientSecretIssuance.transaction do
        at = Client.database_now
        issuance.update!(presented_at: at) unless scenario == :unpresented
        unless scenario == :unaudited
          ClientSecretAuditOutbox.record!(
            actor_context: context, client_ref: actor.public_id,
            credential_ref: ((scenario == :mismatched_presented) ? "N" * 21 : candidate.public_id),
            operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
          )
        end
      end
      case scenario
      when :no_step_up then token.update!(last_step_up_at: nil)
      when :wrong_scope then token.update!(last_step_up_scope: "settings_passkey")
      when :wrong_session then token = ClientToken.create!(user: actor)
      when :wrong_owner
        context = context.with(subject: Client.create!(status_id: ClientStatus::ACTIVE))
      when :expired_step_up then token.update!(last_step_up_at: ClientToken.database_now - 16.minutes)
      when :revoked then token.update!(discard_at: ClientToken.database_now)
      when :restricted then token.update!(user_token_status_id: ClientTokenStatus::RESTRICTED)
      when :secret_method then token.update!(last_step_up_method: "secret")
      when :extra_candidate
        extra = SecureRandom.base58(32)
        ClientSecretCredential.create!(
          client: actor, issuance: issuance, name: "Unpresented addition", password: extra,
          lookup_digest: SignSecretLookupDigest.digest(extra),
        )
      end
      failure =
        %i(unaudited mismatched_presented extra_candidate).include?(scenario) ?
          ClientSecretStorageConfirmationCommitter::InvalidState :
          ClientSecretStorageConfirmationCommitter::Denied
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(failure) do
          ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
        end
      end
      assert_nil issuance.reload.confirmed_at
      assert_nil candidate.reload.confirmed_at
      assert_nil ClientSecretLookupQuery.call(secret: raw)
    end
  end

  [-1, 0, 1].each do |offset|
    test "confirmation evaluates issuance expiry #{offset} microseconds from its boundary" do
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor)
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
        last_step_up_method: "totp", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      )
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
      issuance = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      )
      raw = SecureRandom.base58(32)
      candidate = ClientSecretCredential.create!(
        client: actor, issuance: issuance, name: "Boundary value", password: raw,
        lookup_digest: SignSecretLookupDigest.digest(raw),
      )
      ClientSecretAuditOutbox.transaction do
        at = Client.database_now
        issuance.update!(presented_at: at)
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
          operation_ref: issuance.origin_operation_id, occurred_at: at, event_name: "secret.presented", item_count: 1,
        )
      end
      decision_at = issuance.expires_at + Rational(offset, 1_000_000)
      Client.stub(:database_now, decision_at) do
        if offset.negative?
          ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)

          assert_equal decision_at, issuance.reload.confirmed_at
          assert_equal decision_at, candidate.reload.confirmed_at
        else
          assert_no_difference("ClientSecretAuditOutbox.count") do
            assert_raises(ClientSecretStorageConfirmationCommitter::Denied) do
              ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
            end
          end
          assert_nil issuance.reload.confirmed_at
          assert_nil candidate.reload.confirmed_at
        end
      end
    end
  end
end
