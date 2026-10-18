# frozen_string_literal: true

require "test_helper"

class ClientSecretCredentialRebuildTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "eligibility depends on credential facts rather than account state" do
    now = Time.utc(2026, 10, 3, 22, 0)
    credential = ClientSecretCredential.new(confirmed_at: now)

    assert credential.available_at?(at: now)
    credential.claimed_at = now
    credential.claim_operation_id = SecureRandom.uuid

    assert_not credential.available_at?(at: now)
    credential = ClientSecretCredential.new(confirmed_at: now, revoked_at: now)

    assert_not credential.available_at?(at: now)
    assert_not ClientSecretCredential.new.available_at?(at: now)
  end

  test "discard boundary is unavailable at equality and afterward" do
    deadline = Time.utc(2026, 10, 3, 22, 1)
    credential = ClientSecretCredential.new(confirmed_at: deadline - 1.minute, discard_at: deadline)

    assert credential.available_at?(at: deadline - 0.000001)
    assert_not credential.available_at?(at: deadline)
    assert_not credential.available_at?(at: deadline + 0.000001)
  end

  test "whole secret verification accepts the exact server generated value only" do
    raw = SecureRandom.base58(32)
    credential = ClientSecretCredential.new(password: raw)

    assert credential.matches_secret?(raw)
    assert_not credential.matches_secret?(SecureRandom.base58(32))
    assert_not credential.matches_secret?(raw.reverse)
  end

  test "secret format rejects adjacent lengths missing values types and forbidden alphabet" do
    raw = "a" * 32
    credential = ClientSecretCredential.new(password: raw)

    ["a" * 31, "a" * 33, "", nil, 0, [], {}, ("a" * 31) + "\0", "0" * 32].each do |input|
      assert_not credential.matches_secret?(input)
    end
    assert credential.matches_secret?(raw)
    assert_not credential.matches_secret?(raw.upcase)
  end

  test "verification rejects invalid UTF-8 and UTF-16 input without raising or normalizing" do
    raw = "a" * 32
    credential = ClientSecretCredential.new(password: raw)

    ["\xFF".b.force_encoding("UTF-8") * 32, raw.encode("UTF-16LE")].each do |input|
      assert_not credential.matches_secret?(input)
    end
    assert credential.matches_secret?(raw)
  end
end

class ClientSecretCredentialPersistenceTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    clients client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_secret_credentials client_secret_issuances
  )

  test "unconfirmed candidate persists without a recovery identity and cannot rotate its secret" do
    owner = clients(:placeholder)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: owner, origin_operation_id: SecureRandom.uuid, origin: "manual",
      attempt_number: 1, browser_session_ref: "server-issued-session", planned_count: 1,
      expires_at: now + 1.minute,
    )
    raw = SecureRandom.base58(32)
    credential = ClientSecretCredential.create!(
      client: owner, issuance: issuance, name: "Secret", password: raw,
    )

    credential.reload

    assert_equal owner.id, credential.client_id
    assert_not credential.available_at?(at: now)
    assert credential.matches_secret?(raw)
    assert_equal 1, owner.client_secret_credentials.count
    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.update!(password: SecureRandom.base58(32)) }
    assert credential.reload.matches_secret?(raw)
  end

  test "ordinary assignment and raw attribute persistence cannot introduce an unaudited revocation" do
    credential = client_secret_credentials(:one)
    now = ClientSecretCredential.database_now

    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.update!(revoked_at: now) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.reload.write_attribute(:revoked_at, now) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.reload.update_columns(revoked_at: now) }
    assert_nil credential.reload.revoked_at
    assert credential.available_at?(at: now)
  end

  test "failed source audit rolls back revocation and closes the lifecycle write interval" do
    actor = clients(:one)
    actor.client_passkeys.create!(
      webauthn_id: "revocation-source-failure-key", public_key: "synthetic-public-key",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    now = ClientSecretCredential.database_now
    assert_no_difference("ClientSecretAuditOutbox.count") do
      # UUID generation failure reaches real source-event validation, not a success mock.
      SecureRandom.stub(:uuid, nil) do
        assert_raises(ActiveRecord::RecordInvalid) do
          credential.commit_management_revocation!(actor_context: context, at: now, purge_at: now + 1.day)
        end
      end
    end
    assert_nil credential.reload.revoked_at
    assert_equal Float::INFINITY, credential.discard_at
    assert credential.available_at?(at: now)
    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.write_attribute(:revoked_at, now) }
    assert_nil credential.reload.revoked_at
  end

  test "persisted logical discard cannot be cleared replaced or restored through public writers" do
    credential = client_secret_credentials(:one)
    discarded_at = ClientSecretCredential.database_now.round(6)
    credential.update!(discard_at: discarded_at)
    snapshot = credential.reload.attributes

    [
      Float::INFINITY, nil, discarded_at - Rational(1, 1_000_000), discarded_at,
      discarded_at + Rational(1, 1_000_000),
    ].each do |value|
      assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.reload.update!(discard_at: value) }
      assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.reload.write_attribute(:discard_at, value) }
      assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.reload.update_column(:discard_at, value) }
      assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.reload.update_columns(discard_at: value) }
      assert_equal snapshot, credential.reload.attributes
      assert_not credential.available_at?(at: discarded_at)
    end

    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.reload.touch(:discard_at) }
    assert_equal snapshot, credential.reload.attributes
  end

  test "name changes on a discarded secret preserve the irreversible discard fact" do
    credential = client_secret_credentials(:one)
    discarded_at = ClientSecretCredential.database_now.round(6)
    credential.update!(discard_at: discarded_at)
    credential.update!(name: "Retired Secret")

    assert_equal "Retired Secret", credential.reload.name
    assert_equal discarded_at, credential.discard_at
    assert_not credential.available_at?(at: discarded_at)
  end

  test "withdrawal anonymization retains Secret audit and removes credential authentication" do
    owner = Client.create!(
      status_id: ClientStatus::ACTIVE, withdrawn_at: Client.database_now,
      terminated_at: Client.database_now,
    )
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: owner, origin_operation_id: SecureRandom.uuid, origin: "manual",
      attempt_number: 1, browser_session_ref: "withdrawal-session", planned_count: 1,
      expires_at: now + 1.minute, encrypted_payload: "opaque-test-payload",
    )
    raw = SecureRandom.base58(32)
    credential = ClientSecretCredential.create!(
      client: owner, issuance: issuance, name: "Pending Secret", password: raw,
    )
    previous_delay = ENV["APP_SECRET_PURGE_DELAY_SECONDS"]
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"

    assert_same owner, WithdrawalPersonalDataAnonymizer.call(actor: owner)
    assert issuance.reload.canceled_at
    assert_nil issuance.encrypted_payload
    assert_equal 0, issuance.reserved_count(at: Client.database_now)
    assert credential.reload.revoked_at
    assert_operator credential.discard_at, :<=, Client.database_now
    assert_nil ClientSecretLookupQuery.call(client: owner, secret: raw)
    assert ClientSecretAuditOutbox.exists?(credential_ref: credential.public_id, event_name: "secret.revoked")
    assert ClientSecretAuditOutbox.exists?(credential_ref: credential.public_id, event_name: "secret.discarded")
  ensure
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = previous_delay
  end

  test "withdrawal without Secret records preserves the existing no-issuance path" do
    now = Client.database_now
    owner = Client.create!(status_id: ClientStatus::ACTIVE, withdrawn_at: now, terminated_at: now)
    previous_delay = ENV.delete("APP_SECRET_PURGE_DELAY_SECONDS")
    assert_no_difference ["ClientSecretCredential.count", "ClientSecretIssuance.count",
                          "ClientSecretAuditOutbox.count",] do
      assert_same owner, WithdrawalPersonalDataAnonymizer.call(actor: owner)
    end
    assert_predicate owner.reload, :terminated?
  ensure
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = previous_delay
  end
end
