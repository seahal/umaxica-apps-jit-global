# frozen_string_literal: true

require "test_helper"

class AvatarOwnershipPeriodSourceTest < ActiveSupport::TestCase
  setup do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    @avatar = @bootstrap.avatar
  end

  test "post-cutover reads and scoped relations use the concrete owner period" do
    AvatarRecord.transaction(joinable: false) do
      AvatarOwnershipCutover.create!(
        id: AvatarOwnershipCutover::CUTOVER_ID,
        cutover_at: Time.utc(2030, 1, 1),
      )

      selected = @avatar.current_ownership_period

      assert_instance_of AvatarEnterpriseOwnershipPeriod, selected
      assert_equal @bootstrap.collective.public_id, selected.owner_collective_public_id

      relation = AvatarOwnershipPeriodSource.relation_for(
        Avatar.all,
        surface: "app",
        collective_public_id: @bootstrap.collective.public_id,
      )

      assert_includes relation.where(id: @avatar.id).pluck(:id), @avatar.id
      raise ActiveRecord::Rollback
    end
  end

  test "post-cutover scoped relations normalize a symbol owner surface" do
    AvatarRecord.transaction(joinable: false) do
      AvatarOwnershipCutover.create!(
        id: AvatarOwnershipCutover::CUTOVER_ID,
        cutover_at: Time.utc(2030, 1, 1),
      )

      relation = AvatarOwnershipPeriodSource.relation_for(
        Avatar.all,
        surface: :app,
        collective_public_id: @bootstrap.collective.public_id,
      )

      assert_includes relation.where(id: @avatar.id).pluck(:id), @avatar.id
      raise ActiveRecord::Rollback
    end
  end
end
