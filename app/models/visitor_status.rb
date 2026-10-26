# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_statuses
# Database name: com_principal
#
#  id :bigint           not null, primary key
#

class VisitorStatus < ComPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  NOTHING = 2
  RESERVED = 3
  # D-128 (WU-34): the same registration states as APP. A COM candidate is created unfinished and its
  # Finalization promotes it to ACTIVE (the decisive commit, D-131).
  UNVERIFIED_WITH_SIGN_UP = 4
  VERIFIED_WITH_SIGN_UP = 5
  DEFAULTS = [ACTIVE, NOTHING, RESERVED, UNVERIFIED_WITH_SIGN_UP, VERIFIED_WITH_SIGN_UP].freeze

  has_many :visitors,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :visitor_status
end
