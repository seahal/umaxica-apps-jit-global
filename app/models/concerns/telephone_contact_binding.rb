# typed: false
# frozen_string_literal: true

# Durable ownership facts for an telephone binding. A candidate may
# share a destination with other candidates; only a finalized, unreleased row
# participates in identity lookup and cardinality.
# Requires contact_binding_digest, accessible? and self.class.database_now from the concrete model.
module TelephoneContactBinding
  extend ActiveSupport::Concern

  public

  def binding_effective?
    binding_finalized_at.present? && binding_released_at.blank?
  end

  def binding_released?
    binding_released_at.present?
  end

  def finalize_registration_binding!(transaction:, code:, session_ref:)
    with_lock do
      now = self.class.database_now
      unless !binding_finalized_at && !binding_released? && accessible?(now) &&
          registration_ceremony_evidence?(transaction, code, session_ref)
        raise ArgumentError, "verified registration candidate is unavailable"
      end

      key, pending, verified =
        case self
        when ClientTelephone
          [:user_telephone_status_id, ClientTelephoneStatus::UNVERIFIED, ClientTelephoneStatus::VERIFIED]
        when VisitorTelephone
          [:visitor_telephone_status_id, VisitorTelephoneStatus::UNVERIFIED, VisitorTelephoneStatus::VERIFIED]
        else raise ArgumentError, "unsupported registration Contact"
        end
      raise ArgumentError, "registration candidate is not pending" unless self[key] == pending

      update!(key => verified, :binding_finalized_at => now)
      self
    end
  end

  def finalize_binding!(at: self.class.database_now)
    raise ArgumentError, "released contact binding cannot be finalized" if binding_released_at.present?
    return self if binding_finalized_at.present?

    update!(binding_finalized_at: at)
    self
  end

  def release_binding!(at: self.class.database_now)
    raise ArgumentError, "candidate contact binding cannot be released" if binding_finalized_at.blank?
    return self if binding_released_at.present?

    update!(binding_released_at: at)
    self
  end

  def retire_for_withdrawal!
    owner, status_column, suspended =
      case self
      when ClientTelephone then [user, :user_telephone_status_id, ClientTelephoneStatus::SUSPENDED]
      when VisitorTelephone then [visitor, :visitor_telephone_status_id, VisitorTelephoneStatus::SUSPENDED]
      else raise ArgumentError, "unsupported withdrawal telephone"
      end
    owner.with_lock do
      raise ArgumentError, "telephone withdrawal owner is not terminated" unless owner.terminated?

      with_lock do
        now = self.class.database_now
        deadline = owner.purge_eligible_at
        unless deadline == Float::INFINITY || purge_eligible_at == Float::INFINITY
          deadline = [deadline, purge_eligible_at].max
        end
        discarded = [created_at, now].max
        deadline = [deadline, discarded].max unless deadline == Float::INFINITY
        update!(
          status_column => suspended, :otp_private_key => "withdrawn", :otp_counter => "0",
          :otp_expires_at => -Float::INFINITY, :discard_at => discarded,
          :purge_eligible_at => deadline,
        )
      end
    end
    self
  end

  private

  def registration_ceremony_evidence?(transaction, code, session_ref)
    owner =
      case [self, transaction]
      in [ClientTelephone, ClientTelephoneCeremonyTransaction] then user
      in [VisitorTelephone, VisitorTelephoneCeremonyTransaction] then visitor
      else raise ArgumentError, "unsupported Telephone registration ceremony realm"
      end
    transaction.normalized_number_digest == number_digest && transaction.telephone_otp_verified_evidence?(
      code: code, purpose: "credential_registration", actor_ref: owner.public_id, session_ref: session_ref,
      operation: "registration", candidate_ref: public_id,
    )
  end

  def effective_binding_has_digest
    return if binding_finalized_at.blank?
    return if contact_binding_digest.present?

    errors.add(:base, "an effective contact binding requires a destination digest")
  end
end
