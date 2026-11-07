# frozen_string_literal: true

class RpBaseOrgSessionAvatarSelection < RpBaseOrgRecord
  belongs_to :actor_selection,
             class_name: "RpBaseOrgSessionSelection",
             foreign_key: :rp_session_id,
             primary_key: :rp_session_id,
             inverse_of: :avatar_selection

  validates :avatar_public_id, presence: true
  validates :avatar_public_id, format: { with: /\A[0-9A-Za-z_-]{21}\z/ }
  validates :avatar_public_id, length: { maximum: 21 }
  validates :selected_at, presence: true
end
