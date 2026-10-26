# typed: false
# frozen_string_literal: true

require "test_helper"

class RpLocalSchemaContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  LOCAL_SUFFIXES = %w(
    Principal
    IdentityBinding
    OpSessionBinding
    Session
    CallbackState
    EventReceipt
  ).freeze

  test "every configured cell has a fixed record connection and disjoint database" do
    cells = RpCellBinding::CELLS.values
    databases = []

    cells.each do |cell|
      record_class = "#{cell.record_prefix}Record".constantize

      assert_equal cell.connection, record_class.connection_db_config.name
      databases << record_class.connection_db_config.database

      LOCAL_SUFFIXES.each do |suffix|
        model = "#{cell.record_prefix}#{suffix}".constantize

        assert_equal cell.connection, model.connection_db_config.name
        assert_equal cell.realm, model::REALM
        assert_equal cell.client_id, model::CLIENT_ID
      end
    end

    assert_equal cells.length, databases.uniq.length
  end

  test "client lookup cannot select an unknown or request-derived cell" do
    assert_equal "rp_core_app", RpCellBinding.for_client("core-app-jp").connection
    assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.fetch("rp_core_app_jp") }
    assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.for_client("core-app-us") }
  end

  test "local models reject a cross-cell identity binding" do
    principal = RpCoreAppPrincipal.create!
    identity_binding = RpCoreAppIdentityBinding.new(
      principal:,
      issuer: "https://op.example.test",
      realm: "com",
      client_id: "core-app-jp",
      subject: "subject-1",
    )

    assert_not_predicate identity_binding, :valid?
    assert identity_binding.errors.of_kind?(:realm, :inclusion)
  end

  test "database cell constraint rejects an invalid tombstone shape" do
    tombstone = RpCoreAppOpSessionBinding.new(
      issuer: "https://op.example.test",
      realm: "com",
      client_id: "core-app-jp",
      sid: "unknown-sid",
    )

    assert_raises(ActiveRecord::StatementInvalid) { tombstone.save!(validate: false) }
  end

  test "one live local session exists per OP binding and a revocation is absorbing" do
    principal = RpCoreAppPrincipal.create!
    identity_binding = RpCoreAppIdentityBinding.create!(
      principal:,
      issuer: "https://op.example.test",
      realm: "app",
      client_id: "core-app-jp",
      subject: "subject-2",
    )
    op_binding = RpCoreAppOpSessionBinding.create!(
      identity_binding:,
      issuer: "https://op.example.test",
      realm: "app",
      client_id: "core-app-jp",
      sid: "sid-2",
    )
    expires_at = 10.minutes.from_now
    first_session = RpCoreAppSession.create!(op_session_binding: op_binding, absolute_expires_at: expires_at)

    duplicate = RpCoreAppSession.new(op_session_binding: op_binding, absolute_expires_at: expires_at)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }

    revoked_at = Time.current.change(usec: 0)
    op_binding.revoke!(now: revoked_at)
    op_binding.revoke!(now: revoked_at + 1.minute)

    assert_equal revoked_at, op_binding.reload.revoked_at
    assert_not_predicate first_session.reload, :active?
  end
end
