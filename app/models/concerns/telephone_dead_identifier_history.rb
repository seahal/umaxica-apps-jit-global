# frozen_string_literal: true

# Requires self.class.database_now and the concrete identifier's persisted owner FK.
module TelephoneDeadIdentifierHistory
  public

  def dead_telephone_history
    @dead_telephone_history if destroyed?
  end

  private

  def archive_dead_telephone_identifier
    return unless persisted?
    raise ArgumentError, "telephone purge primary key changed" unless id == id_in_database

    history_model, owner_model, owner_key, realm =
      case self
      when ClientTelephone then [ClientTelephoneHistory, Client, :user_id, "app"]
      when VisitorTelephone then [VisitorTelephoneHistory, Visitor, :visitor_id, "com"]
      when OperatorTelephone then [OperatorTelephoneHistory, Operator, :staff_id, "org"]
      else raise ArgumentError, "unsupported telephone archive model"
      end
    owner_id = self.class.where(id: id).pick(owner_key)
    raise ActiveRecord::RecordNotFound, "telephone identifier already purged" unless owner_id

    owner = owner_model.find(owner_id)
    owner.with_lock do
      current = self.class.lock.find(id)
      unless current[owner_key] == owner.id && self[owner_key] == owner.id
        raise ArgumentError, "telephone archive owner mismatch"
      end

      now = self.class.database_now
      refuse_retained_telephone_destruction!(current, now)
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
        errors.add(:base, "telephone identifier is legally retained")
        throw(:abort)
      end

      fingerprint = IdentifierHistoryFingerprintVerifier.create(
        identifier: current.number, realm: realm, channel: "telephone",
      )
      @dead_telephone_history = history_model.create!(
        owner_key => owner.id, :fingerprint => fingerprint, :attached_at => current.created_at,
        :detached_at => now, :created_at => now,
      )
    end
  end

  def refuse_retained_telephone_destruction!(current, now)
    return unless current.is_a?(ClientTelephone) || current.is_a?(VisitorTelephone)
    return if current.discard_at == Float::INFINITY && current.purge_eligible_at == Float::INFINITY
    return if current.lapsed?(now) && current.purgeable?(now)

    errors.add(:base, "telephone identifier remains recoverable or retained")
    throw(:abort)
  end
end
