# typed: false
# == Schema Information
#
# Table name: avatar_assignments
# Database name: avatar
#
#  id         :bigint           not null, primary key
#  role       :string(50)       default("viewer"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  avatar_id  :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_avatar_assignments_on_user_id          (user_id)
#  index_avatar_assignments_unique              (avatar_id,user_id,role) UNIQUE
#  index_avatar_assignments_unique_affiliation  (avatar_id) UNIQUE WHERE ((role)::text = 'affiliation'::text)
#  index_avatar_assignments_unique_owner        (avatar_id) UNIQUE WHERE ((role)::text = 'owner'::text)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id) ON DELETE => cascade
#

# frozen_string_literal: true

require "test_helper"

class AvatarAssignmentTest < ActiveSupport::TestCase
  setup do
    ensure_reference_rows!
  end

  test "should have ROLES constant" do
    assert_equal %w(owner affiliation administrator editor reviewer viewer),
                 AvatarAssignment::ROLES
  end

  test "should validate role inclusion" do
    assignment = AvatarAssignment.new(role: "invalid_role")

    assert_not assignment.valid?
    assert_predicate assignment.errors[:role], :present?
  end

  test "should allow valid roles" do
    AvatarAssignment::ROLES.each do |role|
      assignment = AvatarAssignment.new(role: role)
      assignment.valid?
      # Role should not have "not included" error
      assert_not assignment.errors[:role].any? { |msg| msg.include?("一覧") || msg.include?("included") }
    end
  end

  test "last owner assignment cannot be destroyed" do
    owner = create_assignment(role: "owner")

    assert_no_difference -> { AvatarAssignment.count } do
      assert_not owner.destroy
    end

    assert_equal :last_avatar_owner_assignment, owner.errors.details.fetch(:base).first.fetch(:error)
  end

  test "destroy bang raises when destroying the last owner assignment" do
    owner = create_assignment(role: "owner")

    assert_no_difference -> { AvatarAssignment.count } do
      assert_raises(ActiveRecord::RecordNotDestroyed) { owner.destroy! }
    end
  end

  test "owner assignment remains unique for an avatar" do
    avatar = create_avatar
    create_assignment(avatar: avatar, role: "owner")

    duplicate = AvatarAssignment.new(avatar: avatar, user: create_user, role: "owner")

    assert_not duplicate.valid?
    assert_equal :taken, duplicate.errors.details.fetch(:avatar_id).first.fetch(:error)
  end

  test "last administrator assignment cannot be destroyed" do
    administrator = create_assignment(role: "administrator")

    assert_no_difference -> { AvatarAssignment.count } do
      assert_not administrator.destroy
    end

    assert_equal :last_avatar_administrator_assignment, administrator.errors.details.fetch(:base).first.fetch(:error)
  end

  test "administrator assignment can be destroyed when another administrator remains" do
    avatar = create_avatar
    administrator = create_assignment(avatar: avatar, role: "administrator")
    create_assignment(avatar: avatar, role: "administrator")

    assert_difference -> { AvatarAssignment.count }, -1 do
      assert administrator.destroy
    end
  end

  test "non protected assignment can be destroyed" do
    viewer = create_assignment(role: "viewer")

    assert_difference -> { AvatarAssignment.count }, -1 do
      assert viewer.destroy
    end
  end

  test "last owner assignment cannot be demoted" do
    owner = create_assignment(role: "owner")

    assert_no_changes -> { owner.reload.role } do
      owner.role = "editor"

      assert_not owner.save
    end

    assert_equal :last_avatar_owner_assignment, owner.errors.details.fetch(:base).first.fetch(:error)
  end

  test "last owner assignment cannot be changed to administrator" do
    owner = create_assignment(role: "owner")

    assert_no_changes -> { owner.reload.role } do
      owner.role = "administrator"

      assert_not owner.save
    end

    assert_equal :last_avatar_owner_assignment, owner.errors.details.fetch(:base).first.fetch(:error)
  end

  test "last administrator assignment cannot be demoted" do
    administrator = create_assignment(role: "administrator")

    assert_no_changes -> { administrator.reload.role } do
      administrator.role = "viewer"

      assert_not administrator.save
    end

    assert_equal :last_avatar_administrator_assignment, administrator.errors.details.fetch(:base).first.fetch(:error)
  end

  test "last administrator assignment cannot be changed to owner" do
    administrator = create_assignment(role: "administrator")

    assert_no_changes -> { administrator.reload.role } do
      administrator.role = "owner"

      assert_not administrator.save
    end

    assert_equal :last_avatar_administrator_assignment, administrator.errors.details.fetch(:base).first.fetch(:error)
  end

  test "administrator assignment can change role when another administrator remains" do
    avatar = create_avatar
    administrator = create_assignment(avatar: avatar, role: "administrator")
    create_assignment(avatar: avatar, role: "administrator")

    assert_changes -> { administrator.reload.role }, from: "administrator", to: "editor" do
      administrator.update!(role: "editor")
    end
  end

  test "unrelated updates on last owner and administrator are allowed" do
    owner = create_assignment(role: "owner")
    administrator = create_assignment(role: "administrator")

    assert owner.update(updated_at: Time.current)
    assert administrator.update(updated_at: Time.current)
  end

  test "creating first owner and administrator assignments works" do
    avatar = create_avatar

    assert_difference -> { AvatarAssignment.count }, 2 do
      create_assignment(avatar: avatar, role: "owner")
      create_assignment(avatar: avatar, role: "administrator")
    end
  end

  test "avatar persona binding is not consulted for assignment authority protection" do
    avatar = create_avatar
    owner = create_assignment(avatar: avatar, role: "owner")
    AvatarPersonaBinding.create!(avatar: avatar, persona: create_persona)

    assert_no_difference -> { AvatarAssignment.count } do
      assert_not owner.destroy
    end

    assert_equal :last_avatar_owner_assignment, owner.errors.details.fetch(:base).first.fetch(:error)
  end

  private

  def ensure_reference_rows!
    [ClientStatus, ClientVisibility, ClientIdentityState, HandleStatus].each do |klass|
      klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!)
    end
    AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
  end

  def create_assignment(avatar: create_avatar, user: create_user, role:)
    AvatarAssignment.create!(avatar: avatar, user: user, role: role)
  end

  def create_avatar
    handle = Handle.create!(
      handle: "avatar-assignment-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )

    Avatar.create!(
      moniker: "Assignment Test Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
  end

  def create_user
    Client.create!(
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def create_persona
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-assignment-persona-#{SecureRandom.hex(4)}",
      audience: "acme_app",
      source_record_id: SecureRandom.random_number(1_000_000) + 5000,
      status_id: ClientIdentityState::ACTIVE,
    )
    ClientPersona.create!(client_identity: identity, moniker: "Assignment ClientPersona", title: "Persona01")
  end
end
