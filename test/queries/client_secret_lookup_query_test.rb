# frozen_string_literal: true

require "test_helper"

class ClientSecretLookupQueryTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    clients client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_secret_credentials client_secret_issuances
  )

  test "any confirmed Secret resolves its owner without contact information or public ID input" do
    assert_equal client_secret_credentials(:one).id, ClientSecretLookupQuery.call(secret: "a" * 32).id
    assert_equal client_secret_credentials(:two).id, ClientSecretLookupQuery.call(secret: "b" * 32).id
    assert_equal client_secret_credentials(:sample_login).id, ClientSecretLookupQuery.call(secret: "c" * 32).id
  end

  test "invalid format unknown value and exact case mismatch return no credential without mutation" do
    before_count = ClientSecretCredential.count

    [nil, "", 0, [], {}, "a" * 31, "a" * 33, "0" * 32, ("a" * 31) + "\0", "A" * 32, "z" * 32].each do |input|
      assert_nil ClientSecretLookupQuery.call(secret: input)
    end

    assert_equal before_count, ClientSecretCredential.count
    assert_nil client_secret_credentials(:one).reload.claimed_at
    assert_nil client_secret_credentials(:two).reload.claimed_at
  end

  test "invalid UTF-8 and non ASCII compatible strings are rejected without raising or claiming" do
    ["\xFF".b.force_encoding("UTF-8") * 32, ("a" * 32).encode("UTF-16LE")].each do |input|
      assert_nil ClientSecretLookupQuery.call(secret: input)
    end
    assert_nil client_secret_credentials(:one).reload.claimed_at
  end

  test "pending claimed revoked and discarded rows never resolve as usable credentials" do
    owner = clients(:placeholder)
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
        lookup_digest: SignSecretLookupDigest.digest(raw),
        confirmed_at: (state == :pending) ? nil : now,
        claimed_at: (state == :claimed) ? now : nil,
        claim_operation_id: (state == :claimed) ? SecureRandom.uuid : nil,
        revoked_at: (state == :revoked) ? now : nil,
        discard_at: (state == :discarded) ? now : Float::INFINITY,
      )

      assert_nil ClientSecretLookupQuery.call(secret: raw)
    end
  end

  test "lookup digest match alone does not replace whole value password verification" do
    owner = clients(:placeholder)
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: owner, origin_operation_id: SecureRandom.uuid, origin: "manual",
      attempt_number: 1, browser_session_ref: "server-issued-session", planned_count: 1,
      expires_at: now + 1.hour, presented_at: now, confirmed_at: now,
    )
    ClientSecretCredential.create!(
      client: owner, issuance: issuance, name: "Fixture Secret", password: "d" * 32,
      lookup_digest: SignSecretLookupDigest.digest("e" * 32), confirmed_at: now,
    )

    assert_nil ClientSecretLookupQuery.call(secret: "e" * 32)
    assert_nil ClientSecretLookupQuery.call(secret: "d" * 32)
  end
end
