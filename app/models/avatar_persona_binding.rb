# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_persona_bindings
# Database name: avatar
#
#  id          :bigint           not null, primary key
#  assigned_at :datetime         not null
#  avatar_id   :bigint           not null
#  created_at  :datetime         not null
#  persona_id  :bigint           not null
#  public_id   :string(21)       not null
#  revoked_at  :datetime
#  updated_at  :datetime         not null
#
# Indexes
#
#  idx_avatar_persona_bindings_active_avatar  (avatar_id) UNIQUE WHERE (revoked_at IS NULL)
#  idx_avatar_persona_bindings_active_pair    (avatar_id,persona_id) UNIQUE WHERE (revoked_at IS NULL)
#  idx_avatar_persona_bindings_active_persona (persona_id) UNIQUE WHERE (revoked_at IS NULL)
#  index_avatar_persona_bindings_on_avatar_id  (avatar_id)
#  index_avatar_persona_bindings_on_persona_id (persona_id)
#  index_avatar_persona_bindings_on_public_id  (public_id) UNIQUE
#
class AvatarPersonaBinding < AvatarRecord
  include PublicId
  include AvatarPersonaBindingRevocation

  before_validation :default_assigned_at, on: :create

  scope :active, -> { where(revoked_at: nil) }

  belongs_to :avatar, inverse_of: :avatar_persona_binding
  belongs_to :persona, class_name: "ClientPersona", inverse_of: :avatar_persona_binding

  validates :assigned_at, presence: true
  validates :revoked_at,
            comparison: { greater_than_or_equal_to: :assigned_at },
            if: -> { assigned_at.present? && revoked_at.present? }
  validates :avatar_id, uniqueness: { conditions: -> { active } }, if: :active?
  validates :persona_id, uniqueness: { conditions: -> { active } }, if: :active?

  private

  def default_assigned_at
    self.assigned_at ||= Time.current
  end
end
