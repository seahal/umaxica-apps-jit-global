# typed: false
# frozen_string_literal: true

# Selects the explicitly staged Group ownership-period authority. Before the verified Avatar
# cutover marker, the legacy table remains the writer and reader. After the marker, only the
# concrete table is selected; no legacy fallback is attempted.
class AvatarGroupOwnershipPeriodSource
  class << self
    public

    def model
      AvatarOwnershipCutover.established? ? AvatarGroupConcreteOwnershipPeriod : AvatarGroupOwnershipPeriod
    end

    def all_for(group)
      model.where(avatar_group_id: group.id)
    end

    def current_for(group)
      current.find_by(avatar_group_id: group.id)
    end

    delegate :current, to: :model
    delegate :create!, to: :model
  end
end
