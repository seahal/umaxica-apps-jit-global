# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: member_statuses
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class MemberStatus < AppPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  INACTIVE = 2
  PENDING = 3
  DELETED = 4
  NOTHING = 5
  DEFAULTS = [ACTIVE, INACTIVE, PENDING, DELETED, NOTHING].freeze

  has_many :members,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :member_status

  validates :created_at, :updated_at, presence: true
end
