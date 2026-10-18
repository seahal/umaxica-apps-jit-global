# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: handles
# Database name: avatar
#
#  id               :bigint           not null, primary key
#  cooldown_until   :datetime         not null
#  handle           :string           not null
#  is_system        :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  handle_status_id :bigint
#  public_id        :string           not null
#
# Indexes
#
#  index_handles_on_cooldown_until    (cooldown_until)
#  index_handles_on_handle_status_id  (handle_status_id)
#  index_handles_on_is_system         (is_system)
#  index_handles_on_public_id         (public_id) UNIQUE
#  uniq_handles_handle_non_system     (handle) UNIQUE WHERE (is_system = false)
#
# Foreign Keys
#
#  fk_rails_...  (handle_status_id => handle_statuses.id)
#

require "test_helper"
require_relative "../support/avatar_test_factory"

class HandleTest < ActiveSupport::TestCase
  setup do
    @handle = Handle.new(
      handle: "valid_handle",
      cooldown_until: Time.current,
    )
  end

  test "valid handle" do
    assert_predicate @handle, :valid?
    assert @handle.save
  end

  test "requires handle" do
    @handle.handle = nil

    assert_not @handle.valid?
    assert_not_empty @handle.errors[:handle]
  end

  test "requires cooldown_until" do
    @handle.cooldown_until = nil

    assert_not @handle.valid?
    assert_not_empty @handle.errors[:cooldown_until]
  end

  test "handle uniqueness for non-system" do
    Handle.create!(handle: "taken", cooldown_until: Time.current)
    duplicate = Handle.new(handle: "taken", cooldown_until: Time.current)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:handle]
  end

  test "handle is invalid when empty" do
    @handle.handle = ""

    assert_not @handle.valid?
    assert_not_empty @handle.errors[:handle]
  end

  test "handle is invalid when only whitespace" do
    @handle.handle = "   "

    assert_not @handle.valid?
    assert_not_empty @handle.errors[:handle]
  end

  test "public_id uniqueness" do
    @handle.save!
    duplicate = Handle.new(
      handle: "new_handle",
      cooldown_until: Time.current,
      public_id: @handle.public_id,
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:public_id]
  end

  test "association deletion: restriction by active_avatars" do
    @handle.save!
    capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    AvatarTestFactory.create!(
      moniker: "Handle Avatar",
      active_handle: @handle,
      capability: capability,
    )

    assert_not @handle.destroy
    assert @handle.errors[:base].any? { |message| message.include?("active avatars") }
  end
end
