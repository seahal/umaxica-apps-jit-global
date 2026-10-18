# typed: false
# frozen_string_literal: true

require "test_helper"

# Per-surface stores and typed payload envelopes. Each refuses a surface, subject
# or payload shape it was not built for, because the alternative is writing one
# surface's ceremony into another's table, or delivering a message assembled from
# two mutually exclusive payload formats.
class CeremonyReplayStoreAndPayloadRefusalsTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  test "a surface with no telephone ceremony table is refused rather than defaulted" do
    error = assert_raises(IdentityTelephoneCeremony::Error) { IdentityTelephoneCeremonyReplayStore.for("martian") }

    assert_match(/surface is invalid/, error.message)
  end

  test "a transaction round-trips through the store it was created by and is seen as consumed once" do
    store = IdentityTelephoneCeremonyReplayStore.for("app")
    created = store.create_transaction!(actor_ref: "actor-1", session_ref: "session-1", operation: "registration")

    assert_equal created.transaction_id, store.find_transaction!(created.transaction_id).transaction_id
    assert_not store.consumed?("never-issued-jti")

    created.update!(result_jti: "issued-jti")

    assert store.consumed?("issued-jti")
    assert_raises(ActiveRecord::RecordNotFound) { store.find_transaction!("no-such-transaction") }
  end
end
