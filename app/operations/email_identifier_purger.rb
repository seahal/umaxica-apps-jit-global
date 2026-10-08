# frozen_string_literal: true

class EmailIdentifierPurger
  class << self
    public

    def call(record:)
      owner, database =
        case record
        when ClientEmail then [record.user, AppZenithRecord]
        when VisitorEmail then [record.visitor, ComZenithRecord]
        when OperatorEmail then [record.staff, OrgZenithRecord]
        else raise ArgumentError, "unsupported email identifier"
        end
      unless owner && (record.persisted? || record.destroyed?)
        raise ArgumentError, "email purge requires a persisted identifier and owner"
      end

      database.connected_to(role: :writing) do
        owner.with_lock do
          current = record.class.lock.find_by(id: record.id)
          return nil unless current

          actual_owner_id =
            case current
            when ClientEmail then current.user_id
            when VisitorEmail then current.visitor_id
            when OperatorEmail then current.staff_id
            end
          raise ArgumentError, "email purge owner mismatch" unless actual_owner_id == owner.id

          now = record.class.database_now
          return nil unless purge_permitted?(current, owner, now)

          current.destroy!
          current.dead_email_history
        end
      end
    end

    private

    def purge_permitted?(current, owner, now)
      eligible =
        case current
        when ClientEmail, VisitorEmail then current.lapsed?(now) && current.purgeable?(now)
        when OperatorEmail then owner.lapsed?(now) && owner.purgeable?(now)
        end
      raise ArgumentError, "email identifier is still live or recoverable" unless eligible

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
