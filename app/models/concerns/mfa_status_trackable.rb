# typed: false
# frozen_string_literal: true

module MfaStatusTrackable
  extend ActiveSupport::Concern

  class InvalidMfaStatus < StandardError; end
  REFERENCE_CLASSES = Concurrent::Map.new

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    before_validation :assign_calculated_mfa_status, if: :mfa_status_placeholder?
    after_create :refresh_mfa_status!
  end

  class_methods do
    def mfa_status_reference(model_class)
      REFERENCE_CLASSES[self] = model_class
    end

    def mfa_status_reference_class
      REFERENCE_CLASSES.fetch(self)
    end
  end

  def refresh_mfa_status!
    return true unless persisted? && has_attribute?(:mfa_status_id)

    next_status_id = calculated_mfa_status_id
    return true if mfa_status_id.to_i == next_status_id

    ActiveRecord::Base.connected_to(role: :writing) do
      assign_attributes(mfa_status_update_attributes(next_status_id))
      save!
    end
  end

  def mfa_status_active?
    return false unless has_attribute?(:mfa_status_id)

    normalized_mfa_status_id == mfa_status_active_id
  end

  def mfa_status_unconfigured?
    return false unless has_attribute?(:mfa_status_id)

    normalized_mfa_status_id == mfa_status_unconfigured_id
  end

  private

  def assign_calculated_mfa_status
    self.mfa_status_id = calculated_mfa_status_id
  end

  def mfa_status_placeholder?
    has_attribute?(:mfa_status_id) &&
      mfa_status_id.to_i == mfa_status_nothing_id
  end

  def normalized_mfa_status_id
    status_id = mfa_status_id.to_i
    return status_id unless status_id == mfa_status_nothing_id

    raise InvalidMfaStatus,
          "#{self.class.name}##{id || "new"} has placeholder mfa_status_id=#{status_id}"
  end

  def calculated_mfa_status_id
    configured_mfa_level_methods.any? ? mfa_status_active_id : mfa_status_unconfigured_id
  end

  def mfa_status_update_attributes(next_status_id)
    attributes = { mfa_status_id: next_status_id }
    attributes[:updated_at] = Time.current if has_attribute?(:updated_at)
    attributes
  end

  def configured_mfa_level_methods
    []
  end

  def mfa_status_active_id
    self.class.mfa_status_reference_class::ACTIVE
  end

  def mfa_status_nothing_id
    self.class.mfa_status_reference_class::NOTHING
  end

  def mfa_status_unconfigured_id
    self.class.mfa_status_reference_class::UNCONFIGURED
  end
end
