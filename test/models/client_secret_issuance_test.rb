# frozen_string_literal: true

require "test_helper"

class ClientSecretIssuanceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "zero planned candidates is terminal omission without an expiry or reservation" do
    issuance = ClientSecretIssuance.new(planned_count: 0)
    now = Time.utc(2026, 10, 3, 21, 0)

    assert_equal :omitted, issuance.state(at: now)
    assert_equal :omitted, issuance.state(at: now + 1.year)
    assert_equal 0, issuance.reserved_count(at: now)
  end

  test "positive pending batch reserves its immutable count before and after presentation" do
    now = Time.utc(2026, 10, 3, 21, 0)
    issuance = ClientSecretIssuance.new(planned_count: 2, expires_at: now + 1.minute)

    assert_equal :pending_presentation, issuance.state(at: now)
    assert_equal 2, issuance.reserved_count(at: now)
    issuance.presented_at = now

    assert_equal :pending_confirmation, issuance.state(at: now)
    assert_equal 2, issuance.reserved_count(at: now)
  end

  test "reservation classification immediately before at and after its exact deadline" do
    deadline = Time.utc(2026, 10, 3, 21, 1)
    issuance = ClientSecretIssuance.new(planned_count: 1, expires_at: deadline)

    assert_equal :pending_presentation, issuance.state(at: deadline - 0.000001)
    assert_equal 1, issuance.reserved_count(at: deadline - 0.000001)
    assert_equal :expired, issuance.state(at: deadline)
    assert_equal 0, issuance.reserved_count(at: deadline)
    assert_equal :expired, issuance.state(at: deadline + 0.000001)
    assert_equal 0, issuance.reserved_count(at: deadline + 0.000001)
  end

  test "confirmation and cancellation retain their terminal facts after expiry" do
    now = Time.utc(2026, 10, 3, 21, 0)
    confirmed = ClientSecretIssuance.new(
      planned_count: 2, presented_at: now, confirmed_at: now + 1.second, expires_at: now + 1.minute,
    )
    canceled = ClientSecretIssuance.new(planned_count: 1, canceled_at: now, expires_at: now + 1.minute)

    assert_equal :confirmed, confirmed.state(at: now + 1.hour)
    assert_equal 0, confirmed.reserved_count(at: now + 1.hour)
    assert_equal :canceled, canceled.state(at: now + 1.hour)
    assert_equal 0, canceled.reserved_count(at: now + 1.hour)
  end

  test "contradictory terminal facts raise instead of releasing capacity silently" do
    now = Time.utc(2026, 10, 3, 21, 0)
    issuance = ClientSecretIssuance.new(
      planned_count: 2, presented_at: now, confirmed_at: now,
      canceled_at: now, expires_at: now + 1.minute,
    )

    assert_raises(ArgumentError) { issuance.state(at: now) }
  end

  test "omission rejects expiry delivery cancellation and payload facts" do
    now = Time.utc(2026, 10, 3, 21, 0)
    [
      { expires_at: now }, { presented_at: now }, { confirmed_at: now },
      { canceled_at: now }, { encrypted_payload: "encrypted fixture" },
    ].each do |facts|
      issuance = ClientSecretIssuance.new(planned_count: 0, **facts)

      assert_raises(ArgumentError) { issuance.state(at: now) }
    end
  end

  test "planned count boundaries reject minus one and three and accept zero one two" do
    now = Time.utc(2026, 10, 3, 21, 0)
    [-1, 3, nil].each do |count|
      issuance = ClientSecretIssuance.new(planned_count: count)

      assert_raises(ArgumentError) { issuance.state(at: now) }
    end
    [1, 2].each do |count|
      issuance = ClientSecretIssuance.new(planned_count: count, expires_at: now + 1.minute)

      assert_equal count, issuance.reserved_count(at: now)
    end
    assert_equal 0, ClientSecretIssuance.new(planned_count: 0).reserved_count(at: now)
  end

  test "confirmation requires presentation and must precede the exact expiry" do
    deadline = Time.utc(2026, 10, 3, 21, 1)
    [deadline, deadline + 0.000001].each do |time|
      issuance = ClientSecretIssuance.new(
        planned_count: 1, presented_at: deadline - 1.second, confirmed_at: time, expires_at: deadline,
      )

      assert_raises(ArgumentError) { issuance.state(at: time) }
    end
    issuance = ClientSecretIssuance.new(
      planned_count: 1, presented_at: deadline - 1.second,
      confirmed_at: deadline - 0.000001, expires_at: deadline,
    )

    assert_equal :confirmed, issuance.state(at: deadline)

    unpresented = ClientSecretIssuance.new(
      planned_count: 1, confirmed_at: deadline - 1.second, expires_at: deadline,
    )
    assert_raises(ArgumentError) { unpresented.state(at: deadline) }
    no_expiry = ClientSecretIssuance.new(planned_count: 1)
    assert_raises(ArgumentError) { no_expiry.state(at: deadline) }
  end
end

class ClientSecretIssuancePersistenceTest < ActiveSupport::TestCase
  test "completed presentation and confirmation facts resist direct clearing and timestamp replacement" do
    issuance = client_secret_issuances(:one)
    snapshot = issuance.attributes

    %i(confirmed_at presented_at).each do |attribute|
      original = issuance[attribute]
      [nil, original - Rational(1, 1_000_000), original, original + Rational(1, 1_000_000)].each do |replacement|
        assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.update_columns(attribute => replacement) }
        assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.update_column(attribute, replacement) }
        if replacement == original
          issuance.reload.write_attribute(attribute, replacement)

          assert issuance.update!(attribute => replacement)
        else
          assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.write_attribute(attribute, replacement) }
          assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.update!(attribute => replacement) }
        end

        assert_equal snapshot, issuance.reload.attributes
        assert_equal :confirmed, issuance.state(at: Client.database_now)
        assert_equal 0, issuance.reserved_count(at: Client.database_now)
      end
      assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.touch(attribute) }
      assert_equal snapshot, issuance.reload.attributes
    end
  end

  test "canceled issuance cannot restore reservation or change its terminal timestamp through direct writes" do
    now = Client.database_now.round(6)
    issuance = ClientSecretIssuance.create!(
      client: clients(:one), origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: "terminal-cancellation-probe", planned_count: 1,
      expires_at: now + 1.minute, canceled_at: now,
    )
    snapshot = issuance.reload.attributes

    [nil, now - Rational(1, 1_000_000), now, now + Rational(1, 1_000_000)].each do |replacement|
      assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.update_columns(canceled_at: replacement) }
      assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.update_column(:canceled_at, replacement) }
      if replacement == now
        issuance.reload.write_attribute(:canceled_at, replacement)

        assert issuance.update!(canceled_at: replacement)
      else
        assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.write_attribute(:canceled_at, replacement) }
        assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.update!(canceled_at: replacement) }
      end

      assert_equal snapshot, issuance.reload.attributes
      assert_equal :canceled, issuance.state(at: now)
      assert_equal 0, issuance.reserved_count(at: now)
    end
    assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.reload.touch(:canceled_at) }
    assert_equal snapshot, issuance.reload.attributes
  end
end
