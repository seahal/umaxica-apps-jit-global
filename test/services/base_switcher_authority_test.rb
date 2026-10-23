# frozen_string_literal: true

require "test_helper"

class BaseSwitcherAuthorityTest < ActiveSupport::TestCase
  test "post-cutover candidate resolution uses concrete Avatar ownership" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)

    AvatarRecord.transaction(joinable: false) do
      AvatarOwnershipCutover.create!(
        id: AvatarOwnershipCutover::CUTOVER_ID,
        cutover_at: Time.utc(2030, 1, 1),
      )

      avatars = BaseSwitcherAuthority.new(surface: :app, principal: actor).available_avatars

      assert_includes avatars.map(&:id), bootstrap.avatar.id
      assert_instance_of AvatarEnterpriseOwnershipPeriod, bootstrap.avatar.current_ownership_period

      # Roll back the marker and synthetic graph through the ordinary test transaction.
      raise ActiveRecord::Rollback
    end
  end
end
