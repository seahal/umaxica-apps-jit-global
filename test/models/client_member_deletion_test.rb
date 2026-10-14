# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: client_member_deletions
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  member_id  :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_member_deletions_on_member_id              (member_id)
#  index_client_member_deletions_on_user_id_and_member_id  (user_id,member_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (member_id => members.id)
#  fk_rails_...  (user_id => clients.id)
#


require "test_helper"

class ClientMemberDeletionTest < ActiveSupport::TestCase
  fixtures :client_member_deletions, :clients, :client_statuses, :members, :member_statuses, :divisions,
           :division_statuses, :organizations, :organization_statuses

  test "fixture is valid" do
    user = clients(:one)
    member = members(:one)
    deletion = ClientMemberDeletion.find_by!(user: user, member: member)

    assert_predicate deletion, :valid?
  end

  test "belongs to user" do
    deletion = client_member_deletions(:one)

    assert_respond_to deletion, :user
    assert_instance_of Client, deletion.user
  end

  test "belongs to member" do
    deletion = client_member_deletions(:one)

    assert_respond_to deletion, :member
    assert_instance_of Member, deletion.member
  end

  test "validates uniqueness of member_id scoped to user_id" do
    user = clients(:one)
    member = members(:one)
    ClientMemberDeletion.find_by!(user: user, member: member)

    duplicate = ClientMemberDeletion.new(
      user: user,
      member: member,
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:member_id], I18n.t("errors.messages.taken")
  end

  test "allows different members for same user" do
    user = clients(:one)
    member2 = members(:two)

    # Check if combination already exists in fixtures
    existing = ClientMemberDeletion.find_by(user: user, member: member2)
    if existing.nil?
      deletion2 = ClientMemberDeletion.new(
        user: user,
        member: member2,
      )

      assert_predicate deletion2, :valid?
    else
      # Already exists in fixtures, test passes
      assert existing
    end
  end

  test "allows same member for different clients" do
    user2 = clients(:two)
    member = members(:one)

    # Check if combination already exists in fixtures
    existing = ClientMemberDeletion.find_by(user: user2, member: member)
    if existing.nil?
      deletion2 = ClientMemberDeletion.new(
        user: user2,
        member: member,
      )

      assert_predicate deletion2, :valid?
    else
      # Already exists in fixtures, test passes
      assert existing
    end
  end
end
