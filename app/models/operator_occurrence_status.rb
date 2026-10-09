# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_occurrence_statuses
# Database name: occurrence
#
#  id   :bigint           not null, primary key
#  name :string           default(""), not null
#

class OperatorOccurrenceStatus < OccurrenceRecord
  include ReferenceRecord

  include OccurrenceStatus

  # Fixed IDs - do not modify these values
  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4
  DEFAULTS = [NOTHING, ACTIVE, INACTIVE, DELETED].freeze

  has_many :staff_occurrences,
           class_name: "OperatorOccurrence",
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :staff_occurrence_status
end
