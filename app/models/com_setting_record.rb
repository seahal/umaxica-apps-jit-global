# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class ComSettingRecord < ApplicationRecord
  self.abstract_class = true
  self.strict_loading_by_default = true

  connects_to database: { writing: :com_setting, reading: :com_setting_replica }

  before_validation :set_next_position, if: -> { self.class.column_names.include?("position") }

  private

  def set_next_position
    # Always calculate next position to ensure uniqueness
    # This prevents position conflicts when rows are inserted concurrently.
    self.position = (self.class.maximum(:position) || 0) + 1
  end
end
