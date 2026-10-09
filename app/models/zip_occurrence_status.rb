# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: zip_occurrence_statuses
# Database name: occurrence
#
#  id :bigint           not null, primary key
#

class ZipOccurrenceStatus < OccurrenceRecord
  include ReferenceRecord
  include OccurrenceStatus

  # Fixed IDs - do not modify these values
  NOTHING = 0
  ACTIVE = 1
  LEGACY_NOTHING = 2
  DEFAULTS = [NOTHING, ACTIVE, LEGACY_NOTHING].freeze

  has_many :zip_occurrences, foreign_key: :status_id, dependent: :restrict_with_error,
                             inverse_of: :zip_occurrence_status

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
