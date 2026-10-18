# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_agent_bindings
# Database name: avatar
#
#  agent_id    :bigint           not null
#  assigned_at :datetime         not null
#  avatar_id   :bigint           not null
#  created_at  :datetime         not null
#  id          :bigint           not null, primary key
#  public_id   :string(21)       not null
#  revoked_at  :datetime
#  updated_at  :datetime         not null
#
# Indexes
#
#  idx_avatar_agent_bindings_active_agent  (agent_id) UNIQUE WHERE (revoked_at IS NULL)
#  idx_avatar_agent_bindings_active_avatar (avatar_id) UNIQUE WHERE (revoked_at IS NULL)
#  idx_avatar_agent_bindings_active_pair   (avatar_id,agent_id) UNIQUE WHERE (revoked_at IS NULL)
#  index_avatar_agent_bindings_on_agent_id  (agent_id)
#  index_avatar_agent_bindings_on_avatar_id (avatar_id)
#  index_avatar_agent_bindings_on_public_id (public_id) UNIQUE
#
class AvatarAgentBinding < AvatarRecord
  include PublicId
  include AvatarPersonaBindingRevocation

  belongs_to :avatar, inverse_of: :avatar_agent_binding
  belongs_to :agent, inverse_of: :avatar_agent_binding

  validates :assigned_at, presence: true
  validates :revoked_at,
            comparison: { greater_than_or_equal_to: :assigned_at },
            if: -> { assigned_at.present? && revoked_at.present? }
  validates :avatar_id, uniqueness: { conditions: -> { active } }, if: :active?
  validates :agent_id, uniqueness: { conditions: -> { active } }, if: :active?

  before_validation :default_assigned_at, on: :create

  scope :active, -> { where(revoked_at: nil) }

  private

  def default_assigned_at
    self.assigned_at ||= Time.current
  end
end
