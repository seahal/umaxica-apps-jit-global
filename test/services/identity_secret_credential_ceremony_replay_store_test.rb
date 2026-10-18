# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySecretCredentialCeremonyReplayStoreTest < ActiveSupport::TestCase
  test "for returns stores for known surfaces and rejects an unknown surface" do
    assert_kind_of IdentitySecretCredentialCeremonyReplayStore,
                   IdentitySecretCredentialCeremonyReplayStore.for(:app)
    assert_kind_of IdentitySecretCredentialCeremonyReplayStore,
                   IdentitySecretCredentialCeremonyReplayStore.for(:com)
    assert_kind_of IdentitySecretCredentialCeremonyReplayStore,
                   IdentitySecretCredentialCeremonyReplayStore.for(:org)
    assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
      IdentitySecretCredentialCeremonyReplayStore.for(:invalid)
    end
  end

  test "delegates creation and lookup and translates a missing transaction" do
    model = Object.new
    model.define_singleton_method(:create_transaction!) { |**attributes| attributes }
    model.define_singleton_method(:find_by!) do |transaction_id:|
      raise ActiveRecord::RecordNotFound if transaction_id == "missing"

      { transaction_id: transaction_id }
    end
    store = IdentitySecretCredentialCeremonyReplayStore.new(model)

    assert_equal({ transaction_id: "created" }, store.create_transaction!(transaction_id: "created"))
    assert_equal({ transaction_id: "found" }, store.find_transaction!("found"))
    error =
      assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
        store.find_transaction!("missing")
      end
    assert_equal "transaction is not found", error.message
  end

  %w(app com org).each do |surface|
    test "#{surface} generated ceremony transaction and grant references are NanoID-21 values" do
      transaction = IdentitySecretCredentialCeremonyReplayStore.for(surface).create_transaction!(
        actor_ref: "actor-#{surface}", session_ref: "session-#{surface}", operation: "enrollment",
      )

      assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.transaction_id)
      assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.grant_jti)
      assert_not_equal transaction.transaction_id, transaction.grant_jti
    end
  end

  test "retries a generated transaction reference collision at the database boundary" do
    model = ClientSecretCredentialCeremonyTransaction
    model.create_transaction!(
      transaction_id: "a" * 21, grant_jti: "e" * 21,
      actor_ref: "existing-actor", session_ref: "existing-session", operation: "enrollment",
    )
    generated = ["a" * 21, "g" * 21, "b" * 21, "h" * 21]

    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        model.create_transaction!(
          actor_ref: "new-actor", session_ref: "new-session", operation: "enrollment",
        )
      end

    assert_equal "b" * 21, transaction.transaction_id
    assert_equal "h" * 21, transaction.grant_jti
  end

  test "retries a generated grant reference collision at the database boundary" do
    model = ClientSecretCredentialCeremonyTransaction
    model.create_transaction!(
      transaction_id: "j" * 21, grant_jti: "i" * 21,
      actor_ref: "existing-actor", session_ref: "existing-session", operation: "enrollment",
    )
    generated = ["k" * 21, "i" * 21, "l" * 21, "m" * 21]

    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        model.create_transaction!(
          actor_ref: "new-actor", session_ref: "new-session", operation: "enrollment",
        )
      end

    assert_equal "l" * 21, transaction.transaction_id
    assert_equal "m" * 21, transaction.grant_jti
  end
end
