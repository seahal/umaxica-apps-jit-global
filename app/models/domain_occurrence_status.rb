# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_occurrence_statuses
# Database name: occurrence
#
#  id :bigint           not null, primary key
#

class DomainOccurrenceStatus < OccurrenceRecord
  include ReferenceRecord

  include OccurrenceStatus

  # Fixed IDs - do not modify these values
  NOTHING = 0
  ACTIVE = 1
  DELETED = 2
  INACTIVE = 3
  LEGACY_NOTHING = 4
  PENDING = 5
  DEFAULTS = [NOTHING, ACTIVE, DELETED, INACTIVE, LEGACY_NOTHING, PENDING].freeze

  has_many :domain_occurrences, foreign_key: :status_id, dependent: :restrict_with_error,
                                inverse_of: :domain_occurrence_status

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
