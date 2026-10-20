# typed: false
# frozen_string_literal: true

# Current Avatar lifecycle state authority.
class AvatarLifecycleState < AvatarRecord
  validates :can_create_content, :visible_by_default, :editable_by_owner, :restorable_by_owner,
            :followable, :group_attachable, :discoverable, :moderation_visible, :terminal,
            inclusion: { in: [true, false] }, on: :create

  validates :key, presence: true, uniqueness: true
  validates :title, presence: true
  validates :sort_order, presence: true, uniqueness: true
end
