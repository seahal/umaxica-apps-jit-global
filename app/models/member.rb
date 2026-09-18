# typed: false
# == Schema Information
#
# Table name: members
# Database name: app_principal
#
#  id           :bigint           not null, primary key
#  discarded_at :datetime         default(Infinity), not null
#  moniker      :string
#  purged_at    :datetime         default(Infinity), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  division_id  :bigint
#  public_id    :string           not null
#  status_id    :bigint           default(5), not null
#  user_id      :bigint
#
# Indexes
#
#  index_members_on_division_id  (division_id)
#  index_members_on_public_id    (public_id) UNIQUE
#  index_members_on_purged_at    (purged_at)
#  index_members_on_status_id    (status_id)
#  index_members_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => member_statuses.id)
#  fk_rails_...  (user_id => clients.id) ON DELETE => nullify
#

# frozen_string_literal: true

class Member < AppPrincipalRecord
  include Retainable

  attribute :status_id, default: MemberStatus::NOTHING

  belongs_to :user, class_name: "Client", inverse_of: :owned_members
  belongs_to :member_status,
             foreign_key: :status_id,
             inverse_of: :members
  has_many :avatars, foreign_key: :client_id, dependent: :nullify, inverse_of: :member
  has_many :member_avatar_accesses, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_visibilities, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_oversights, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_extractions, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_impersonations, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_suspensions, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_deletions, dependent: :destroy, inverse_of: :member
  has_many :client_member_discoveries,
           class_name: "ClientMemberDiscovery",
           dependent: :destroy,
           inverse_of: :member
  has_many :client_member_observations,
           class_name: "ClientMemberObservation",
           dependent: :destroy,
           inverse_of: :member
  has_many :client_member_revocations,
           class_name: "ClientMemberRevocation",
           dependent: :destroy,
           inverse_of: :member
  has_many :client_member_impersonations,
           class_name: "ClientMemberImpersonation",
           dependent: :destroy,
           inverse_of: :member
  has_many :client_member_suspensions,
           class_name: "ClientMemberSuspension",
           dependent: :destroy,
           inverse_of: :member
  has_many :client_member_deletions,
           class_name: "ClientMemberDeletion",
           dependent: :destroy,
           inverse_of: :member
  has_many :client_members, dependent: :destroy
  has_many :users, class_name: "Client", through: :client_members
end
