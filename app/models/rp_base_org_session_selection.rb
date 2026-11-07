# typed: false
# frozen_string_literal: true

class RpBaseOrgSessionSelection < RpBaseOrgRecord
  belongs_to :rp_session, class_name: "RpBaseOrgSession", inverse_of: :actor_selection
  has_one :avatar_selection,
          class_name: "RpBaseOrgSessionAvatarSelection",
          foreign_key: :rp_session_id,
          primary_key: :rp_session_id,
          inverse_of: :actor_selection,
          dependent: :destroy

  validates :account_public_id, :organization_public_id, :organization_unit_public_id, presence: true
  validates :account_public_id, :organization_public_id, :organization_unit_public_id,
            format: { with: /\A[0-9A-Za-z_-]{21}\z/ }
  validates :account_public_id, :organization_public_id, :organization_unit_public_id,
            length: { maximum: 21 }
  validates :selected_at, presence: true
end
