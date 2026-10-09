# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: handle_assignments
# Database name: avatar
#
#  id                          :bigint           not null, primary key
#  valid_from                  :datetime         not null
#  valid_to                    :datetime         default(Infinity), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  assigned_by_actor_id        :bigint
#  avatar_id                   :bigint           not null
#  handle_assignment_status_id :bigint
#  handle_id                   :bigint           not null
#
# Indexes
#
#  index_handle_assignments_on_assigned_by_actor_id         (assigned_by_actor_id)
#  index_handle_assignments_on_avatar_id                    (avatar_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_handle_assignments_on_avatar_id_and_valid_from     (avatar_id,valid_from DESC)
#  index_handle_assignments_on_handle_assignment_status_id  (handle_assignment_status_id)
#  index_handle_assignments_on_handle_id                    (handle_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_handle_assignments_on_handle_id_and_valid_from     (handle_id,valid_from DESC)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)
#  fk_rails_...  (handle_assignment_status_id => handle_assignment_statuses.id)
#  fk_rails_...  (handle_id => handles.id)
#

require "forwardable"

class HandleAssignment < AvatarRecord
  attribute :handle_assignment_status_id, default: HandleAssignmentStatus::NOTHING

  belongs_to :handle, inverse_of: :handle_assignments
  belongs_to :avatar, inverse_of: :handle_assignments
  belongs_to :assigned_by_actor, class_name: "Avatar", inverse_of: :assignments_created, optional: true
  belongs_to :handle_assignment_status

  validates :valid_from, presence: true
  validates :handle_id, uniqueness: { conditions: -> { current } }
  validates :avatar_id, uniqueness: { conditions: -> { current } }

  delegate :name, to: :handle

  scope :current, -> { where(valid_to: Float::INFINITY) }

  def self.current_attributes
    [:handle_id, :avatar_id]
  end
end
