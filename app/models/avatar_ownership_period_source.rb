# typed: false
# frozen_string_literal: true

# Selects the verified Avatar ownership authority. The legacy period table remains the source
# before the explicit cutover marker. After cutover, only the concrete Enterprise/Bureau period
# tables are read and written; no legacy fallback is attempted.
class AvatarOwnershipPeriodSource
  OWNER_SURFACES = %w(app org).freeze

  class << self
    public

    def legacy?
      !AvatarOwnershipCutover.established?
    end

    def current_for(avatar, lock: false)
      return legacy_current_for(avatar, lock: lock) if legacy?

      periods = concrete_periods_for(avatar, current: true, lock: lock)
      return periods.first if periods.one?

      raise InvalidState, "Avatar has an invalid concrete ownership state"
    end

    def all_for(avatar, lock: false)
      return legacy_periods_for(avatar, lock: lock) if legacy?

      concrete_periods_for(avatar, current: false, lock: lock).sort_by { |period| [period.valid_from, period.id] }
    end

    def create!(avatar:, owner_surface:, owner_collective_public_id:, valid_from:,
                transferred_by_actor_public_id: nil)
      validate_owner!(owner_surface, owner_collective_public_id)
      if legacy?
        status = AvatarOwnershipStatus.find_or_create_by!(id: AvatarOwnershipStatus::ACTIVE)
        return AvatarOwnershipPeriod.create!(
          avatar: avatar,
          owner_organization_id: owner_collective_public_id,
          owner_surface: owner_surface,
          owner_collective_public_id: owner_collective_public_id,
          avatar_ownership_status: status,
          valid_from: valid_from,
        )
      end

      concrete_period_class_for(owner_surface).create!(
        :avatar => avatar,
        owner_attribute_for(owner_surface) => owner_collective_public_id,
        :valid_from => valid_from,
        :transferred_by_actor_public_id => transferred_by_actor_public_id,
      )
    end

    def relation_for(relation, surface:, collective_public_id:)
      surface = surface.to_s
      return relation.none unless OWNER_SURFACES.include?(surface) && collective_public_id.present?
      return relation.joins(:current_ownership_period).where(
        avatar_ownership_periods: {
          owner_surface: surface,
          owner_collective_public_id: collective_public_id,
        },
      ) if legacy?

      period_class = concrete_period_class_for(surface)
      table = period_class.table_name
      relation
        .joins((surface == "app") ? :enterprise_ownership_periods : :bureau_ownership_periods)
        .where(table => { owner_attribute_for(surface) => collective_public_id, :valid_to => Float::INFINITY })
    end

    def concrete_period_class_for(surface)
      case surface.to_s
      when "app" then AvatarEnterpriseOwnershipPeriod
      when "org" then AvatarBureauOwnershipPeriod
      else raise InvalidState, "unsupported Avatar owner surface"
      end
    end

    def owner_attribute_for(surface)
      (surface.to_s == "app") ? :enterprise_public_id : :bureau_public_id
    end

    private

    def legacy_current_for(avatar, lock:)
      relation = AvatarOwnershipPeriod.current
        .where(avatar_id: avatar.id, avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE)
      relation = relation.lock if lock
      relation.first || raise(InvalidState, "Avatar has no current active owner")
    end

    def legacy_periods_for(avatar, lock:)
      relation = avatar.avatar_ownership_periods.order(:valid_from, :id)
      relation = relation.lock if lock
      relation.to_a
    end

    def concrete_periods_for(avatar, current:, lock:)
      relations = [
        AvatarEnterpriseOwnershipPeriod.where(avatar_id: avatar.id),
        AvatarBureauOwnershipPeriod.where(avatar_id: avatar.id),
      ]
      relations.map! { |relation| relation.where(valid_to: Float::INFINITY) } if current
      relations.map!(&:lock) if lock
      relations.flat_map(&:to_a)
    end

    def validate_owner!(surface, public_id)
      raise InvalidState, "unsupported Avatar owner surface" unless OWNER_SURFACES.include?(surface.to_s)
      raise InvalidState, "Avatar owner collective public id is required" if public_id.blank?
    end
  end

  class InvalidState < StandardError; end
end
