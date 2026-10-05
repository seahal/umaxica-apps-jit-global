# frozen_string_literal: true

require "test_helper"

class ClientSecretCapacityQueryTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    clients client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_secret_credentials client_secret_issuances
  )

  test "capacity separates active credentials from a live reservation" do
    client = clients(:placeholder)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: client, origin_operation_id: SecureRandom.uuid, origin: "passkey_registration",
      attempt_number: 1, browser_session_ref: "server-issued-session", planned_count: 2,
      expires_at: now + 1.minute,
    )

    capacity = ClientSecretCapacityQuery.call(client: client, at: now)

    assert_equal 0, capacity.active_count
    assert_equal 2, capacity.reserved_count
    assert_raises(ClientSecretIssuanceCountValue::ReservationConflict) { capacity.passkey_count }
    assert_equal 0, ClientSecretCredential.where(issuance_id: issuance.id).count
  end

  test "confirmed issuance cannot regain a reservation by clearing or replacing its terminal fact" do
    client = clients(:placeholder)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: client, origin_operation_id: SecureRandom.uuid, origin: "passkey_registration",
      attempt_number: 1, browser_session_ref: "confirmed-operation", planned_count: 2,
      presented_at: now, confirmed_at: now + 1.second, expires_at: now + 1.minute,
    )
    2.times do
      raw = SecureRandom.base58(32)
      ClientSecretCredential.create!(
        client: client, issuance: issuance, name: "Confirmed fixture", password: raw,
        lookup_digest: SignSecretLookupDigest.digest(raw), confirmed_at: issuance.confirmed_at,
      )
    end
    terminal = issuance.confirmed_at
    [nil, terminal - Rational(1, 1_000_000), terminal + Rational(1, 1_000_000)].each do |replacement|
      assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.update!(confirmed_at: replacement) }
      assert_equal terminal, issuance.reload.confirmed_at
      capacity = ClientSecretCapacityQuery.call(client: client, at: now + 2.seconds)

      assert_equal 2, capacity.active_count
      assert_equal 0, capacity.reserved_count
    end
    assert issuance.update!(confirmed_at: terminal), "same terminal fact is an ordinary no-op"
    assert_equal :confirmed, issuance.state(at: now + 1.year)
    assert_equal 0, issuance.reserved_count(at: now + 1.year)
  end

  test "presentation fact cannot be cleared or replaced to reopen the one-time delivery phase" do
    client = clients(:placeholder)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: client, origin_operation_id: SecureRandom.uuid, origin: "manual",
      attempt_number: 1, browser_session_ref: "presented-operation", planned_count: 1,
      presented_at: now, expires_at: now + 1.minute,
    )
    [nil, now - Rational(1, 1_000_000), now + Rational(1, 1_000_000)].each do |replacement|
      assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.update!(presented_at: replacement) }
      assert_equal now, issuance.reload.presented_at
      assert_equal :pending_confirmation, issuance.state(at: now + 1.second)
      assert_equal 1, issuance.reserved_count(at: now + 1.second)
    end
    assert issuance.update!(presented_at: now), "same presentation fact is an ordinary no-op"
  end

  test "reservation counts immediately before at and after exact expiry without cleanup jobs" do
    client = clients(:placeholder)
    deadline = Client.database_now + 1.minute
    ClientSecretIssuance.create!(
      client: client, origin_operation_id: SecureRandom.uuid, origin: "manual",
      attempt_number: 1, browser_session_ref: "server-issued-session", planned_count: 1,
      expires_at: deadline,
    )

    assert_equal 1, ClientSecretCapacityQuery.call(client: client, at: deadline - 0.000001).reserved_count
    assert_equal 0, ClientSecretCapacityQuery.call(client: client, at: deadline).reserved_count
    assert_equal 0, ClientSecretCapacityQuery.call(client: client, at: deadline + 0.000001).reserved_count
    assert_equal 0, ClientSecretCapacityQuery.call(client: clients(:two), at: deadline - 0.000001).reserved_count
  end

  test "writer counts zero one eighteen nineteen twenty and rejects corrupted twenty one" do
    client = clients(:placeholder)
    now = Client.database_now
    [0, 1, 18, 19, 20, 21].each do |count|
      AppZenithRecord.transaction(requires_new: true) do
        count.times do
          issuance = ClientSecretIssuance.create!(
            client: client, origin_operation_id: SecureRandom.uuid, origin: "manual",
            attempt_number: 1, browser_session_ref: "server-issued-session", planned_count: 1,
            expires_at: now + 1.hour, presented_at: now, confirmed_at: now,
          )
          raw = SecureRandom.base58(32)
          ClientSecretCredential.create!(
            client: client, issuance: issuance, name: "Fixture Secret", password: raw,
            lookup_digest: SignSecretLookupDigest.digest(raw), confirmed_at: now,
          )
        end
        if count == 21
          assert_raises(ArgumentError) { ClientSecretCapacityQuery.call(client: client, at: now) }
        else
          capacity = ClientSecretCapacityQuery.call(client: client, at: now)

          assert_equal count, capacity.active_count
          assert_equal 0, capacity.reserved_count
          assert_equal(((count <= 18) ? 2 : 20 - count), capacity.passkey_count)
        end
        if count == 18
          ClientSecretIssuance.create!(
            client: client, origin_operation_id: SecureRandom.uuid, origin: "passkey_registration",
            attempt_number: 1, browser_session_ref: "another-server-session", planned_count: 2,
            expires_at: now + 1.hour,
          )
          capacity = ClientSecretCapacityQuery.call(client: client, at: now)

          assert_equal 18, capacity.active_count
          assert_equal 2, capacity.reserved_count
          assert_raises(ClientSecretIssuanceCountValue::ReservationConflict) { capacity.passkey_count }
        end
        raise ActiveRecord::Rollback
      end
    end
  end

  test "reserved account state does not release confirmed credential capacity" do
    client = clients(:reserved_user)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: client, origin_operation_id: SecureRandom.uuid, origin: "manual",
      attempt_number: 1, browser_session_ref: "server-issued-session", planned_count: 1,
      expires_at: now + 1.hour, presented_at: now, confirmed_at: now,
    )
    raw = SecureRandom.base58(32)
    ClientSecretCredential.create!(
      client: client, issuance: issuance, name: "Fixture Secret", password: raw,
      lookup_digest: SignSecretLookupDigest.digest(raw), confirmed_at: now,
    )

    assert_not client.login_allowed?
    assert_equal 1, ClientSecretCapacityQuery.call(client: client, at: now).active_count
  end
end
