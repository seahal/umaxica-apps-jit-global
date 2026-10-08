# frozen_string_literal: true

# Requires self.class.database_now and the concrete identifier's persisted owner FK.
module EmailDeadIdentifierHistory
  public

  def dead_email_history
    @dead_email_history if destroyed?
  end

  private

  def archive_dead_email_identifier
    return unless persisted?
    raise ArgumentError, "email purge primary key changed" unless id == id_in_database

    history_model, owner_model, owner_key, realm =
      case self
      when ClientEmail then [ClientEmailHistory, Client, :user_id, "app"]
      when VisitorEmail then [VisitorEmailHistory, Visitor, :visitor_id, "com"]
      when OperatorEmail then [OperatorEmailHistory, Operator, :staff_id, "org"]
      else raise ArgumentError, "unsupported email archive model"
      end
    owner_id = self.class.where(id: id).pick(owner_key)
    raise ActiveRecord::RecordNotFound, "email identifier already purged" unless owner_id

    owner = owner_model.find(owner_id)
    owner.with_lock do
      current = self.class.lock.find(id)
      unless current[owner_key] == owner.id && self[owner_key] == owner.id
        raise ArgumentError, "email archive owner mismatch"
      end

      refuse_protected_email_destruction!(current)

      now = self.class.database_now
      refuse_retained_email_destruction!(current, now)
      held =
        case owner
        when Client then owner.client_retention_holds.active_at(now).exists?
        when Visitor then owner.visitor_retention_holds.active_at(now).exists?
        when Operator then false
        end
      enforcement =
        case owner
        when Client then AppEnforcementCase
        when Visitor then ComEnforcementCase
        when Operator then OrgEnforcementCase
        end
      if held || enforcement.principal_effect_blocking?(owner.public_id, :withdrawal_purge_blocked) ||
          enforcement.principal_effect_blocking?(owner.public_id, :principal_hard_delete_blocked)
        errors.add(:base, "email identifier is legally retained")
        throw(:abort)
      end

      fingerprint = IdentifierHistoryFingerprintVerifier.create(
        identifier: current.address, realm: realm, channel: "email",
      )
      @dead_email_history = history_model.create!(
        owner_key => owner.id, :fingerprint => fingerprint, :attached_at => current.created_at,
        :detached_at => now, :created_at => now,
      )
    end
  end

  def refuse_protected_email_destruction!(current)
    return unless current.undeletable?

    errors.add(:base, "cannot delete a protected email address")
    throw(:abort)
  end

  def refuse_retained_email_destruction!(current, now)
    return unless current.is_a?(ClientEmail) || current.is_a?(VisitorEmail)
    return if current.discard_at == Float::INFINITY && current.purge_eligible_at == Float::INFINITY
    return if current.lapsed?(now) && current.purgeable?(now)

    errors.add(:base, "email identifier remains recoverable or retained")
    throw(:abort)
  end
end
