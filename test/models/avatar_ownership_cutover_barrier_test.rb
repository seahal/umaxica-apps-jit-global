# frozen_string_literal: true

require "test_helper"

class AvatarOwnershipCutoverBarrierTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    @avatar = @bootstrap.avatar
    @legacy_period = @avatar.avatar_ownership_periods.order(:id).last
    concrete = @avatar.enterprise_ownership_periods.order(:id).last
    @legacy_period.update!(valid_from: concrete.valid_from)
    @transfer = cancelled_transfer
    @group = group_with_ownership
    @group_period = @group.ownership_periods.order(:id).last
  end

  test "legacy writers work before marker and every legacy write kind is rejected after marker" do
    within_avatar_rollback do
      @legacy_period.update!(updated_at: @legacy_period.updated_at + 1.second)

      assert_not AvatarOwnershipCutover.established?

      AvatarOwnershipCutover.create!(
        id: AvatarOwnershipCutover::CUTOVER_ID,
        cutover_at: Time.utc(2030, 1, 1),
      )
      persistence = AvatarRecord.connection.select_value(<<~SQL.squish)
        SELECT relpersistence
        FROM pg_class
        WHERE oid = 'avatar_ownership_cutovers'::regclass
      SQL
      assert_equal "p", persistence

      %w(avatar_ownership_periods avatar_ownership_transfers avatar_group_ownership_periods).each do |table|
        assert_barrier(table, "INSERT INTO #{table} DEFAULT VALUES")
        assert_barrier(table, "UPDATE #{table} SET updated_at = updated_at WHERE id = #{row_id_for(table)}")
        assert_barrier(table, "DELETE FROM #{table} WHERE id = #{row_id_for(table)}")
        assert_barrier(table, "TRUNCATE #{table}")
      end
    end
  end

  test "cutover marker cannot be changed or truncated through direct SQL" do
    within_avatar_rollback do
      AvatarOwnershipCutover.create!(
        id: AvatarOwnershipCutover::CUTOVER_ID,
        cutover_at: Time.utc(2030, 1, 1),
      )

      assert_barrier("avatar_ownership_cutovers", "UPDATE avatar_ownership_cutovers SET cutover_at = cutover_at")
      assert_barrier("avatar_ownership_cutovers", "DELETE FROM avatar_ownership_cutovers")
      assert_barrier("avatar_ownership_cutovers", "TRUNCATE avatar_ownership_cutovers")
    end
  end

  private

  def cancelled_transfer
    AvatarOwnershipTransfer.create!(
      avatar: @avatar,
      public_id: PublicId.generate,
      from_owner_surface: "app",
      from_owner_collective_public_id: @bootstrap.collective.public_id,
      to_owner_surface: "org",
      to_owner_collective_public_id: "barrier-bureau",
      state: "cancelled",
      requested_at: @avatar.created_at,
      expires_at: @avatar.created_at + 5.days,
      cancelled_at: @avatar.created_at + 1.second,
      request_actor_surface: "app",
      request_actor_public_id: @client.public_id,
      cancel_actor_surface: "app",
      cancel_actor_public_id: @client.public_id,
    )
  end

  def group_with_ownership
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: @bootstrap.account.public_id,
      name: "Barrier group #{SecureRandom.hex(4)}",
      state: "active",
    )
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: @bootstrap.collective.public_id,
      valid_from: Time.current,
    )
    legacy_period = group.ownership_periods.order(:id).last
    AvatarGroupConcreteOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: legacy_period.owner_surface,
      owner_collective_public_id: legacy_period.owner_collective_public_id,
      valid_from: legacy_period.valid_from,
      valid_to: legacy_period.valid_to,
    )
    group
  end

  def row_id_for(table)
    {
      "avatar_ownership_periods" => @legacy_period.id,
      "avatar_ownership_transfers" => @transfer.id,
      "avatar_group_ownership_periods" => @group_period.id,
    }.fetch(table)
  end

  def assert_barrier(table, sql)
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        AvatarRecord.transaction(requires_new: true) { AvatarRecord.connection.execute(sql) }
      end
    expected = (table == "avatar_ownership_cutovers") ? "cutover marker is immutable" : "legacy Avatar ownership writes"

    assert_match expected, error.message
    assert_equal "55006", error.cause&.result&.error_field(PG::Result::PG_DIAG_SQLSTATE)
  end

  def within_avatar_rollback
    AvatarRecord.transaction(joinable: false) do
      yield
      raise ActiveRecord::Rollback
    end
  end
end
