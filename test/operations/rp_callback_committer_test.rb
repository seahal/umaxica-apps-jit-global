# frozen_string_literal: true

require "test_helper"

class RpCallbackCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ISSUER = "https://www.umaxica.app"

  setup do
    @cell = RpCellBinding.fetch("rp_core_app")
  end

  test "a first verified callback creates the principal, identity binding, anchor and one live session" do
    result = commit(subject: "subject-a", sid: "sid-1")

    assert_predicate result, :success?
    anchor = RpCoreAppOpSessionBinding.find_by!(sid: "sid-1")

    assert_equal [ISSUER, "app", "core-app-jp"], [anchor.issuer, anchor.realm, anchor.client_id]
    identity = RpCoreAppIdentityBinding.find(anchor.identity_binding_id)

    assert_equal [result.principal.id, "subject-a"], [identity.principal_id, identity.subject]
    assert_equal anchor.id, result.session.op_session_binding_id
    assert_predicate result.session, :active?
  end

  test "the same verified subject on another sid reuses its principal" do
    first = commit(subject: "subject-a", sid: "sid-1")
    second = commit(subject: "subject-a", sid: "sid-2")

    assert_predicate second, :success?
    assert_equal first.principal, second.principal
    assert_equal 1, RpCoreAppPrincipal.count
  end

  test "a second callback for an already enrolled sid is refused" do
    commit(subject: "subject-a", sid: "sid-1")

    assert_equal :already_enrolled, commit(subject: "subject-a", sid: "sid-1").outcome
    assert_equal 1, RpCoreAppSession.count
  end

  test "an anchor bound to one subject never accepts another subject" do
    commit(subject: "subject-a", sid: "sid-1")

    assert_equal :binding_mismatch, commit(subject: "subject-b", sid: "sid-1").outcome
  end

  test "a logged-out sid is a tombstone that a late callback cannot reopen" do
    RpCoreAppOpSessionBinding.create!(
      issuer: ISSUER, realm: "app", client_id: "core-app-jp", sid: "sid-1",
      revoked_at: Time.current,
    )

    result = commit(subject: "subject-a", sid: "sid-1")

    assert_equal :revoked, result.outcome
    assert_equal 0, RpCoreAppSession.count
    assert_nil RpCoreAppOpSessionBinding.find_by!(sid: "sid-1").identity_binding_id
  end

  test "an expired unrevoked session is closed and the sid can enroll again" do
    first = commit(subject: "subject-a", sid: "sid-1")
    first.session.update_columns(absolute_expires_at: 1.minute.ago)

    second = commit(subject: "subject-a", sid: "sid-1")

    assert_predicate second, :success?
    assert_not_nil first.session.reload.revoked_at
  end

  test "blank verified facts are refused before any write" do
    %i(issuer subject sid).each do |field|
      assert_raises(ArgumentError) { commit(:subject => "s", :sid => "x", field => "") }
    end
    assert_equal 0, RpCoreAppOpSessionBinding.count
  end

  test "callback selects its writer even when entered from a reading role" do
    RpCoreAppRecord.connected_to(role: :reading) do
      result = RpCallbackCommitter.call(
        cell: @cell, issuer: ISSUER, subject: "writer-subject", sid: "writer-sid",
        absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
      )

      assert_predicate result, :success?
      assert_not_nil result.session.public_id
    end
  end

  test "callback refuses enrollment for an existing disabled principal" do
    first = RpCallbackCommitter.call(
      cell: @cell, issuer: ISSUER, subject: "disabled-subject", sid: "old-sid",
      absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
    )
    first.principal.update!(disabled_at: Time.current)
    result = RpCallbackCommitter.call(
      cell: @cell, issuer: ISSUER, subject: "disabled-subject", sid: "new-sid",
      absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
    )

    assert_equal :revoked, result.outcome
    assert_nil result.session
    assert_equal 1, RpCoreAppSession.count
    assert_equal 1, RpCoreAppPrincipal.count
  end

  test "callback checks expiry on a fresh writer clock after anchor insertion" do
    base = Time.current.change(usec: 0)
    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each_with_index do |offset, index|
      observations = 0
      clock =
        lambda do
          observations += 1
          (observations <= 2) ? base : base + 5
        end
      RpCoreAppRecord.stub(:database_now, clock) do
        result = RpCallbackCommitter.call(
          cell: @cell, issuer: ISSUER, subject: "expiry-subject", sid: "expiry-#{index}",
          absolute_expires_at: base + 5 + offset, contract_epoch: 1,
        )

        assert_equal offset.positive? ? :committed : :revoked, result.outcome
      end
    end

    assert_equal 1, RpCoreAppSession.count
  end

  private

  def commit(subject:, sid:, issuer: ISSUER)
    RpCallbackCommitter.call(
      cell: @cell, issuer:, subject:, sid:, absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
    )
  end
end
