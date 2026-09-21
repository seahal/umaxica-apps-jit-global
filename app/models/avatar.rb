# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatars
# Database name: avatar
#
#  id                           :bigint           not null, primary key
#  discard_at                 :datetime         default(Infinity), not null
#  image_data                   :jsonb
#  lifecycle_state_id           :bigint           not null
#  lock_version                 :integer          default(0), not null
#  moniker                      :string           not null
#  purge_eligible_at                    :datetime         default(Infinity), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  active_handle_id             :bigint           not null
#  avatar_status_id             :string
#  capability_id                :bigint           default(0), not null
#  client_id                    :bigint
#  owner_organization_id        :string
#  public_id                    :string           not null
#  representing_organization_id :string
#
# Indexes
#
#  index_avatars_on_active_handle_id              (active_handle_id)
#  index_avatars_on_capability_id                 (capability_id)
#  index_avatars_on_client_id                     (client_id)
#  index_avatars_on_lifecycle_state_id            (lifecycle_state_id)
#  index_avatars_on_owner_organization_id         (owner_organization_id)
#  index_avatars_on_public_id                     (public_id) UNIQUE
#  index_avatars_on_purge_eligible_at                     (purge_eligible_at)
#  index_avatars_on_representing_organization_id  (representing_organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (active_handle_id => handles.id)
#  fk_rails_...  (capability_id => avatar_capabilities.id)
#  fk_rails_...  (lifecycle_state_id => avatar_lifecycle_states.id)
#

class Avatar < AvatarRecord
  include Retainable
  include PublicId
  include AvatarImageUploader::Attachment[:image]

  self.belongs_to_required_by_default = false

  belongs_to :member, foreign_key: :client_id, inverse_of: :avatars
  belongs_to :capability, class_name: "AvatarCapability"
  belongs_to :active_handle, class_name: "Handle"
  belongs_to :lifecycle_state, class_name: "AvatarLifecycleState"

  has_many :handle_assignments, dependent: :restrict_with_error
  has_many :assignments_created,
           class_name: "HandleAssignment",
           foreign_key: :assigned_by_actor_id,
           inverse_of: :assigned_by_actor,
           dependent: :restrict_with_error
  has_many :handles, through: :handle_assignments
  has_many :avatar_monikers, dependent: :restrict_with_error
  has_many :avatar_memberships, dependent: :restrict_with_error
  has_many :avatar_ownership_periods, dependent: :restrict_with_error

  # Avatar assignments (role-based access control)
  has_many :avatar_assignments, dependent: :destroy
  has_one :avatar_persona_binding, dependent: :destroy, inverse_of: :avatar
  has_one :avatar_agent_binding, dependent: :destroy, inverse_of: :avatar
  has_one :avatar_individual_binding, dependent: :destroy, inverse_of: :avatar

  has_many :member_avatar_accesses, dependent: :destroy, inverse_of: :avatar
  has_many :member_avatar_visibilities, dependent: :destroy, inverse_of: :avatar
  has_many :member_avatar_oversights, dependent: :destroy, inverse_of: :avatar
  has_many :member_avatar_extractions, dependent: :destroy, inverse_of: :avatar
  has_many :member_avatar_impersonations, dependent: :destroy, inverse_of: :avatar
  has_many :member_avatar_suspensions, dependent: :destroy, inverse_of: :avatar
  has_many :member_avatar_deletions, dependent: :destroy, inverse_of: :avatar
  has_many :avatar_lifecycle_events, dependent: :restrict_with_error, inverse_of: :avatar
  has_many :group_avatar_memberships, dependent: :restrict_with_error, inverse_of: :avatar
  has_many :avatar_groups, through: :group_avatar_memberships

  # Single-user roles (has_one through)
  has_one :owner_assignment,
          -> { where(role: "owner") },
          class_name: "AvatarAssignment",
          inverse_of: :avatar,
          dependent: :destroy
  has_one :owner,
          through: :owner_assignment,
          source: :user,
          disable_joins: true

  has_one :affiliation_assignment,
          -> { where(role: "affiliation") },
          class_name: "AvatarAssignment",
          inverse_of: :avatar,
          dependent: :destroy
  has_one :affiliation_user,
          through: :affiliation_assignment,
          source: :user,
          disable_joins: true

  # Multi-user roles (has_many through)
  has_many :administrator_assignments,
           -> { where(role: "administrator") },
           class_name: "AvatarAssignment",
           inverse_of: :avatar,
           dependent: :destroy
  has_many :administrators,
           through: :administrator_assignments,
           source: :user,
           disable_joins: true

  has_many :editor_assignments,
           -> { where(role: "editor") },
           class_name: "AvatarAssignment",
           inverse_of: :avatar,
           dependent: :destroy
  has_many :editors,
           through: :editor_assignments,
           source: :user,
           disable_joins: true

  has_many :reviewer_assignments,
           -> { where(role: "reviewer") },
           class_name: "AvatarAssignment",
           inverse_of: :avatar,
           dependent: :destroy
  has_many :reviewers,
           through: :reviewer_assignments,
           source: :user,
           disable_joins: true

  has_many :viewer_assignments,
           -> { where(role: "viewer") },
           class_name: "AvatarAssignment",
           inverse_of: :avatar,
           dependent: :destroy

  has_many :viewers,
           through: :viewer_assignments,
           source: :user,
           disable_joins: true

  # follows
  has_many :outgoing_follows,
           class_name: "AvatarFollow",
           foreign_key: :follower_avatar_id,
           inverse_of: :follower_avatar,
           dependent: :destroy

  has_many :incoming_follows,
           class_name: "AvatarFollow",
           foreign_key: :followed_avatar_id,
           inverse_of: :followed_avatar,
           dependent: :destroy

  has_many :followings,
           through: :outgoing_follows,
           source: :followed_avatar

  has_many :followers,
           through: :incoming_follows,
           source: :follower_avatar

  # blocks
  has_many :outgoing_blocks,
           class_name: "AvatarBlock",
           foreign_key: :blocker_avatar_id,
           inverse_of: :blocker_avatar,
           dependent: :destroy

  has_many :blocked_avatars,
           through: :outgoing_blocks,
           source: :blocked_avatar

  has_many :incoming_blocks,
           class_name: "AvatarBlock",
           foreign_key: :blocked_avatar_id,
           inverse_of: :blocked_avatar,
           dependent: :destroy

  has_many :blocking_avatars,
           through: :incoming_blocks,
           source: :blocker_avatar

  # mutes
  has_many :outgoing_mutes,
           class_name: "AvatarMute",
           foreign_key: :muter_avatar_id,
           inverse_of: :muter_avatar,
           dependent: :destroy

  has_many :muted_avatars,
           through: :outgoing_mutes,
           source: :muted_avatar

  has_many :incoming_mutes,
           class_name: "AvatarMute",
           foreign_key: :muted_avatar_id,
           inverse_of: :muted_avatar,
           dependent: :destroy

  has_many :muting_avatars,
           through: :incoming_mutes,
           source: :muter_avatar

  validates :public_id, presence: true, uniqueness: true
  validates :capability_id, numericality: { only_integer: true, greater_than: 0 }
  validates :moniker, presence: true

  before_validation :default_lifecycle_state, on: :create

  # Deprecated compatibility wrapper. New avatar creation must call AvatarProvisioning::Create
  # so the handle, binding, assignment, lifecycle state, and legacy client_id write stay together.
  def self.create_with_owner(attributes, user)
    attributes = attributes.to_h.symbolize_keys
    subject = attributes.delete(:subject)
    subject_type = attributes.delete(:subject_type)
    handle_params = attributes.delete(:handle_params) || {}
    handle_params = handle_params.to_h.symbolize_keys
    handle_params[:handle] ||= attributes.delete(:handle) if attributes.key?(:handle)
    handle_params[:handle] ||= attributes[:active_handle]&.handle if attributes[:active_handle].present?
    assignment_role = attributes.delete(:assignment_role) || AvatarProvisioning::Create::DEFAULT_ASSIGNMENT_ROLE
    organization_public_id =
      attributes.delete(:organization_public_id) ||
      attributes[:owner_organization_id] ||
      attributes[:representing_organization_id]

    result = AvatarProvisioning::Create.call(
      actor: user,
      subject_type: subject_type,
      subject: subject,
      avatar_params: attributes.slice(:moniker),
      handle_params: handle_params,
      assignment_role: assignment_role,
      organization_public_id: organization_public_id,
    )
    raise result.errors.first if result.errors.any?

    result.avatar
  end

  def current_avatar_persona_binding
    return nil unless persisted?

    AvatarPersonaBinding.active.find_by(avatar_id: id)
  end

  def current_persona
    current_avatar_persona_binding&.persona
  end

  private

  def default_lifecycle_state
    self.lifecycle_state ||= AvatarLifecycleState.find_by!(key: "active")
  end
end
