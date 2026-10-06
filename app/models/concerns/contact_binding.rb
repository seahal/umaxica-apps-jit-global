# typed: false
# frozen_string_literal: true

# Durable ownership facts for an email or telephone binding. A candidate may
# share a destination with other candidates; only a finalized, unreleased row
# participates in identity lookup and cardinality.
module ContactBinding
  extend ActiveSupport::Concern

  included do
    scope :effective_binding, -> {
      where.not(binding_finalized_at: nil).where(binding_released_at: nil)
    }

    validate :effective_binding_has_digest
  end

  def binding_effective?
    binding_finalized_at.present? && binding_released_at.blank?
  end

  def binding_released?
    binding_released_at.present?
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
