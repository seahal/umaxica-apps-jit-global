# typed: false
# frozen_string_literal: true

class RpBaseAppSessionSelection < RpBaseAppRecord
  belongs_to :rp_session, class_name: "RpBaseAppSession", inverse_of: :actor_selection

  validates :account_public_id, :organization_public_id, :organization_unit_public_id, :avatar_public_id, presence: true
  validates :account_public_id, :organization_public_id, :organization_unit_public_id, :avatar_public_id,
            format: { with: /\A[0-9A-Za-z_-]{21}\z/ }
  validates :account_public_id, :organization_public_id, :organization_unit_public_id, :avatar_public_id,
            length: { maximum: 21 }
  validates :selected_at, presence: true
end
