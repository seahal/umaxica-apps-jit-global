# frozen_string_literal: true

class TelephoneIdentifierPurger
  class << self
    public

    def call(record:)
      owner, database =
        case record
        when ClientTelephone then [record.user, AppZenithRecord]
        when VisitorTelephone then [record.visitor, ComZenithRecord]
        when OperatorTelephone then [record.staff, OrgZenithRecord]
        else raise ArgumentError, "unsupported telephone identifier"
        end
      unless owner && (record.persisted? || record.destroyed?)
        raise ArgumentError, "telephone purge requires a persisted identifier and owner"
      end

      database.connected_to(role: :writing) do
        owner.with_lock do
          current = record.class.lock.find_by(id: record.id)
          return nil unless current

          actual_owner_id =
            case current
            when ClientTelephone then current.user_id
            when VisitorTelephone then current.visitor_id
            when OperatorTelephone then current.staff_id
            end
          raise ArgumentError, "telephone purge owner mismatch" unless actual_owner_id == owner.id

          now = record.class.database_now
          return nil unless purge_permitted?(current, owner, now)

          current.purge_with_dead_history!
          current.dead_telephone_history
        end
      end
    end

    private

    def purge_permitted?(current, owner, now)
      eligible =
        case current
        when ClientTelephone, VisitorTelephone then current.lapsed?(now) && current.purgeable?(now)
        when OperatorTelephone then owner.lapsed?(now) && owner.purgeable?(now)
        end
      raise ArgumentError, "telephone identifier is still live or recoverable" unless eligible

      held =
        case owner
        when Client then owner.client_retention_holds.active_at(now).exists?
        when Visitor then owner.visitor_retention_holds.active_at(now).exists?
        when Operator then false
        end
      return false if held

      enforcement =
        case owner
        when Client then AppEnforcementCase
        when Visitor then ComEnforcementCase
        when Operator then OrgEnforcementCase
        end
      !enforcement.principal_effect_blocking?(owner.public_id, :withdrawal_purge_blocked) &&
        !enforcement.principal_effect_blocking?(owner.public_id, :principal_hard_delete_blocked)
    end
  end
end
