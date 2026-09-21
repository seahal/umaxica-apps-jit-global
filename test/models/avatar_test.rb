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
#  index_avatars_on_owner_organization_id         (owner_organization_id)
#  index_avatars_on_public_id                     (public_id) UNIQUE
#  index_avatars_on_purge_eligible_at                     (purge_eligible_at)
#  index_avatars_on_representing_organization_id  (representing_organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (active_handle_id => handles.id)
#  fk_rails_...  (capability_id => avatar_capabilities.id)
#

require "test_helper"

class AvatarTest < ActiveSupport::TestCase
  fixtures :avatar_capabilities, :avatars, :handles

  setup do
    create_user_and_status
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(
      handle: "test_handle-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
    )
  end

  test "valid avatar creation" do
    avatar = Avatar.new(
      capability: @capability,
      active_handle: @handle,
      moniker: "Test Client",
      image_data: nil,
    )

    assert_predicate avatar, :valid?
    assert avatar.save
    assert_not_nil avatar.public_id
  end

  test "requires capability" do
    avatar = Avatar.new(active_handle: @handle, moniker: "No Cap", capability_id: nil)

    assert_not avatar.valid?
    assert_not_empty avatar.errors[:capability_id]
  end

  test "requires active_handle" do
    avatar = Avatar.new(capability: @capability, moniker: "No Handle")

    assert_predicate avatar, :valid?
    assert_raises(ActiveRecord::NotNullViolation) { avatar.save! }
  end

  test "requires moniker" do
    avatar = Avatar.new(capability: @capability, active_handle: @handle, moniker: "")

    assert_not avatar.valid?
    assert_not_empty avatar.errors[:moniker]
  end

  test "default image_data is nil until an image is attached" do
    avatar = Avatar.create!(
      capability: @capability,
      active_handle: @handle,
      moniker: "Default Image",
    )

    assert_nil(avatar.image_data)
  end

  test "defaults lifecycle state to active for new avatars" do
    avatar = Avatar.create!(
      capability: @capability,
      active_handle: @handle,
      moniker: "Default Lifecycle",
    )

    assert_equal "active", avatar.lifecycle_state.key
  end

  test "requires lifecycle state id at database level" do
    avatar = Avatar.create!(
      capability: @capability,
      active_handle: @handle,
      moniker: "Lifecycle Null Constraint",
    )

    assert_raises(ActiveRecord::NotNullViolation) do
      Avatar.connection.execute("UPDATE avatars SET lifecycle_state_id = NULL WHERE id = #{avatar.id}")
    end
  end

  test "rejects invalid lifecycle state id at database level" do
    avatar = Avatar.create!(
      capability: @capability,
      active_handle: @handle,
      moniker: "Lifecycle FK Constraint",
    )

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Avatar.connection.execute("UPDATE avatars SET lifecycle_state_id = 999999999 WHERE id = #{avatar.id}")
    end
  end

  test "moniker is invalid when only whitespace" do
    avatar = Avatar.new(capability: @capability, active_handle: @handle, moniker: "   ")

    assert_not avatar.valid?
    assert_not_empty avatar.errors[:moniker]
  end

  test "public_id uniqueness" do
    @avatar = Avatar.create!(
      capability: @capability,
      active_handle: @handle,
      moniker: "Public ID Uniqueness Test",
    )
    duplicate = Avatar.new(
      capability: @capability,
      active_handle: @handle,
      moniker: "Another Moniker",
      public_id: @avatar.public_id,
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:public_id]
  end

  test "create_with_owner creates avatar and assigns owner" do
    create_user_and_status
    user = Client.find_by!(public_id: "one_id")
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)

    avatar = nil
    assert_difference ["Avatar.count", "AvatarAssignment.count", "AvatarPersonaBinding.active.count"], 1 do
      avatar = Avatar.create_with_owner(
        {
          subject_type: :persona,
          subject: bootstrap.account,
          handle_params: { handle: "owned-avatar-wrapper" },
          moniker: "Owned Avatar",
          organization_public_id: bootstrap.collective.public_id,
        }, user,
      )
    end

    assert_equal user, avatar.owner
    assert_includes avatar.avatar_assignments.pluck(:role), "owner"
    assert_equal bootstrap.account, avatar.current_persona
  end

  test "role associations" do
    user = Client.find_by!(public_id: "one_id")
    avatar = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Role Test")

    # Affiliation
    avatar.avatar_assignments.create!(user_id: user.id, role: "affiliation")

    assert_equal user, avatar.affiliation_user

    # Operators
    avatar.avatar_assignments.create!(user_id: user.id, role: "administrator")

    assert_includes avatar.administrators, user

    # Editors
    avatar.avatar_assignments.create!(user_id: user.id, role: "editor")

    assert_includes avatar.editors, user

    # Reviewers
    avatar.avatar_assignments.create!(user_id: user.id, role: "reviewer")

    assert_includes avatar.reviewers, user

    # Viewers
    avatar.avatar_assignments.create!(user_id: user.id, role: "viewer")

    assert_includes avatar.viewers, user
  end

  test "social associations: follows" do
    follower = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Follower")
    followed = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Followed")

    follower.outgoing_follows.create!(followed_avatar: followed)

    assert_includes follower.followings, followed
    assert_includes followed.followers, follower
  end

  test "social associations: blocks" do
    blocker = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Blocker")
    blocked = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Blocked")

    blocker.outgoing_blocks.create!(blocked_avatar: blocked)

    assert_includes blocker.blocked_avatars, blocked
  end

  test "social associations: mutes" do
    muter = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Muter")
    muted = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Muted")

    muter.outgoing_mutes.create!(muted_avatar: muted)

    assert_includes muter.muted_avatars, muted
  end

  test "dependent associations" do
    avatar = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Dependent Test")
    user = Client.find_by!(public_id: "one_id")

    # Assignments
    avatar.avatar_assignments.create!(user_id: user.id, role: "viewer")
    # Follows
    other = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Other")
    avatar.outgoing_follows.create!(followed_avatar: other)
    avatar.incoming_follows.create!(follower_avatar: other)
    # Blocks
    avatar.outgoing_blocks.create!(blocked_avatar: other)
    # Mutes
    avatar.outgoing_mutes.create!(muted_avatar: other)

    assert_difference "AvatarAssignment.count", -1 do
      assert_difference "AvatarFollow.count", -2 do
        assert_difference "AvatarBlock.count", -1 do
          assert_difference "AvatarMute.count", -1 do
            Prosopite.pause { avatar.destroy }
          end
        end
      end
    end
  end

  def create_user_and_status
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    Client.find_or_create_by!(public_id: "one_id") do |u|
      u.status_id = ClientStatus::NOTHING
    end
  end
end
