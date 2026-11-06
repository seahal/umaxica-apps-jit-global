# frozen_string_literal: true

require "test_helper"

class ClientSecretLookupQueryTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    clients client_statuses client_visibilities client_security_modes client_mfa_statuses
    client_secret_credentials client_secret_issuances
  )

  test "a confirmed Secret resolves only inside its explicitly supplied Client" do
    assert_equal client_secret_credentials(:one).id,
                 ClientSecretLookupQuery.call(client: clients(:one), secret: "a" * 32).id
    assert_equal client_secret_credentials(:two).id,
                 ClientSecretLookupQuery.call(client: clients(:two), secret: "b" * 32).id
    assert_equal client_secret_credentials(:sample_login).id,
                 ClientSecretLookupQuery.call(client: clients(:sample_user), secret: "c" * 32).id
  end

  test "equal Secret values on different Clients resolve within the selected owner and choose its lowest ID" do
    raw = SecureRandom.base58(32)
    first_owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    second_owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    unrelated_owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    now = Client.database_now

    first_issuance = ClientSecretIssuance.create!(
      client: first_owner, origin_operation_id: SecureRandom.uuid, origin: "manual",
      attempt_number: 1, browser_session_ref: "first-owner-session", planned_count: 1,
      expires_at: now + 1.hour, presented_at: now, confirmed_at: now,
    )
    first_owner_second_issuance = ClientSecretIssuance.create!(
      client: first_owner, origin_operation_id: SecureRandom.uuid, origin: "manual",
      attempt_number: 1, browser_session_ref: "first-owner-second-session", planned_count: 1,
      expires_at: now + 1.hour, presented_at: now, confirmed_at: now,
    )
    second_issuance = ClientSecretIssuance.create!(
      client: second_owner, origin_operation_id: SecureRandom.uuid, origin: "manual",
      attempt_number: 1, browser_session_ref: "second-owner-session", planned_count: 1,
      expires_at: now + 1.hour, presented_at: now, confirmed_at: now,
    )
    first = ClientSecretCredential.create!(
      client: first_owner, issuance: first_issuance, name: "First", password: raw, confirmed_at: now,
    )
    ClientSecretCredential.create!(
      client: first_owner, issuance: first_owner_second_issuance, name: "Second", password: raw, confirmed_at: now,
    )
    second = ClientSecretCredential.create!(
      client: second_owner, issuance: second_issuance, name: "Other owner", password: raw, confirmed_at: now,
    )

    assert_equal first.id, ClientSecretLookupQuery.call(client: first_owner, secret: raw).id
    assert_equal second.id, ClientSecretLookupQuery.call(client: second_owner, secret: raw).id
    assert_nil ClientSecretLookupQuery.call(client: unrelated_owner, secret: raw)
    assert_nil first.reload.claimed_at
    assert_nil second.reload.claimed_at
  end

  test "invalid format unknown value and exact case mismatch return no credential without mutation" do
    before_count = ClientSecretCredential.count

    [nil, "", 0, [], {}, "a" * 31, "a" * 33, "0" * 32, ("a" * 31) + "\0", "A" * 32, "z" * 32].each do |input|
      assert_nil ClientSecretLookupQuery.call(client: clients(:one), secret: input)
    end

    assert_equal before_count, ClientSecretCredential.count
    assert_nil client_secret_credentials(:one).reload.claimed_at
    assert_nil client_secret_credentials(:two).reload.claimed_at
  end

  test "invalid UTF-8 and non ASCII compatible strings are rejected without raising or claiming" do
    ["\xFF".b.force_encoding("UTF-8") * 32, ("a" * 32).encode("UTF-16LE")].each do |input|
      assert_nil ClientSecretLookupQuery.call(client: clients(:one), secret: input)
    end
    assert_nil client_secret_credentials(:one).reload.claimed_at
  end

  test "pending claimed revoked and discarded rows never resolve as usable credentials" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    now = Client.database_now
    %i(pending claimed revoked discarded).each do |state|
      raw = SecureRandom.base58(32)
      issuance = ClientSecretIssuance.create!(
        client: owner, origin_operation_id: SecureRandom.uuid, origin: "manual",
        attempt_number: 1, browser_session_ref: "server-issued-session", planned_count: 1,
        expires_at: now + 1.hour, presented_at: now,
        confirmed_at: (state == :pending) ? nil : now,
      )
      ClientSecretCredential.create!(
        client: owner, issuance: issuance, name: "Fixture Secret", password: raw,
        confirmed_at: (state == :pending) ? nil : now,
        # The lookup classifies persisted claim facts; claim issuance has its own transaction tests.
        claimed_at: (state == :claimed) ? now : nil,
        claim_operation_id: (state == :claimed) ? SecureRandom.uuid : nil,
        claim_sign_in_flow_ref: (state == :claimed) ? PublicId.generate : nil,
        claim_ceremony_session_id: (state == :claimed) ? 1 : nil,
        revoked_at: (state == :revoked) ? now : nil,
        discard_at: (state == :discarded) ? now : Float::INFINITY,
      )

      assert_nil ClientSecretLookupQuery.call(client: owner, secret: raw)
    end
  end

  test "whole value password verification does not depend on a lookup digest" do
    owner = clients(:placeholder)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: owner, origin_operation_id: SecureRandom.uuid, origin: "manual",
      attempt_number: 1, browser_session_ref: "server-issued-session", planned_count: 1,
      expires_at: now + 1.hour, presented_at: now, confirmed_at: now,
    )
    credential = ClientSecretCredential.create!(
      client: owner, issuance: issuance, name: "Fixture Secret", password: "d" * 32,
      confirmed_at: now,
    )

    assert_nil ClientSecretLookupQuery.call(client: owner, secret: "e" * 32)
    assert_equal credential.id, ClientSecretLookupQuery.call(client: owner, secret: "d" * 32).id
  end
end
