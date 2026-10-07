# typed: false
# frozen_string_literal: true

# Durable ownership facts for an email or telephone binding. A candidate may
# share a destination with other candidates; only a finalized, unreleased row
# participates in identity lookup and cardinality.
module ContactBinding
  extend ActiveSupport::Concern

  public

  def binding_effective?
    binding_finalized_at.present? && binding_released_at.blank?
  end

  def binding_released?
    binding_released_at.present?
  end

  def finalize_registration_binding!
    with_lock do
      now = self.class.database_now
      proof = credential_registration_otp_context
      unless proof&.fetch("verified_at") && Time.iso8601(proof.fetch("result_expires_at")) > now &&
          !binding_finalized_at && !binding_released? && accessible?(now)
        raise ArgumentError, "verified registration candidate is unavailable"
      end

      key, pending, verified =
        case self
        when ClientEmail then [:user_email_status_id, ClientEmailStatus::UNVERIFIED, ClientEmailStatus::VERIFIED]
        when ClientTelephone
          [:user_telephone_status_id, ClientTelephoneStatus::UNVERIFIED, ClientTelephoneStatus::VERIFIED]
        when VisitorEmail then [:visitor_email_status_id, VisitorEmailStatus::UNVERIFIED, VisitorEmailStatus::VERIFIED]
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

  private

  def effective_binding_has_digest
    return if binding_finalized_at.blank?
    return if contact_binding_digest.present?

    errors.add(:base, "an effective contact binding requires a destination digest")
  end
end
