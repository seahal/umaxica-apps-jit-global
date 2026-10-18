# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_occurrence_statuses
# Database name: occurrence
#
#  id   :bigint           not null, primary key
#  name :string           default(""), not null
#
class VisitorOccurrenceStatus < OccurrenceRecord
  include ReferenceRecord

  include OccurrenceStatus

  NOTHING = 0
  ACTIVE = 1
  INACTIVE = 2
  DELETED = 3
  DEFAULTS = [NOTHING, ACTIVE, INACTIVE, DELETED].freeze

  has_many :visitor_occurrences, foreign_key: :status_id, dependent: :restrict_with_error,
                                 inverse_of: :visitor_occurrence_status
end
