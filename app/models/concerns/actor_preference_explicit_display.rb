# frozen_string_literal: true

# Reads only actor display values whose explicit provenance is recorded. The including model must
# implement actor_preference_child_for(field) as a static association map.
module ActorPreferenceExplicitDisplay
  extend ActiveSupport::Concern

  DISPLAY_FIELDS = %w(
    language timezone region theme currency date_format time_format motion density page_size
  ).freeze
  NON_TRANSFERABLE_FIELDS = %w(region).freeze
  ALLOWED_FIELDS = DISPLAY_FIELDS

  public

  def explicit_values
    raise ActiveRecord::RecordNotSaved, "actor preference must be persisted" unless persisted?

    # Child values alone do not establish user intent; only the explicit field list authorizes transfer.
    names = explicit_field_names.uniq
    unsupported = names - ALLOWED_FIELDS
    if unsupported.any?
      raise ArgumentError, "unsupported explicit preference fields: #{unsupported.sort.join(", ")}"
    end

    DISPLAY_FIELDS.each_with_object({}) do |field, snapshot|
      next unless names.include?(field)
      next if NON_TRANSFERABLE_FIELDS.include?(field)

      child = actor_preference_child_for(field)
      option = child&.option
      raise ActiveRecord::RecordNotFound, "explicit #{field} preference has no option record" if option.blank?

      value = option.name
      unless value.is_a?(String) && value.present?
        raise ActiveRecord::RecordNotFound, "explicit #{field} preference has no option name"
      end

      snapshot[field] = value
    end.freeze
  end

  private

  def actor_preference_child_for(field)
    raise NotImplementedError, "#{self.class} must map explicit preference fields"
  end
end
