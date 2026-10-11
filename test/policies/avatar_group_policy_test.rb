# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarGroupPolicyTest < ActiveSupport::TestCase
  setup do
    Actor.install_context!(selection: Actor::SelectedContext.new(account_public_id: "account-1"))
  end

  teardown { Actor.clear }

  test "client can list and create groups" do
    policy = AvatarGroupPolicy.new(AvatarGroup, user: Client.new)

    assert_predicate policy, :index?
    assert_predicate policy, :create?
  end

  test "non-client cannot list or create groups" do
    policy = AvatarGroupPolicy.new(AvatarGroup, user: Visitor.new)

    assert_not policy.index?
    assert_not policy.create?
  end

  test "selected account can show and mutate an active app group" do
    group = AvatarGroup.new(account_surface: "app", account_public_id: "account-1", state: "active")
    policy = AvatarGroupPolicy.new(group, user: Client.new)

    assert_predicate policy, :show?
    assert_predicate policy, :update?
    assert_predicate policy, :destroy?
  end

  test "wrong account surface selection and archived groups are denied" do
    wrong_surface = AvatarGroup.new(account_surface: "org", account_public_id: "account-1", state: "active")
    wrong_account = AvatarGroup.new(account_surface: "app", account_public_id: "account-2", state: "active")
    archived = AvatarGroup.new(
      account_surface: "app", account_public_id: "account-1", state: "archived", archived_at: Time.current,
    )

    assert_not AvatarGroupPolicy.new(wrong_surface, user: Client.new).show?
    assert_not AvatarGroupPolicy.new(wrong_account, user: Client.new).show?
    assert_not AvatarGroupPolicy.new(archived, user: Client.new).update?
    assert_not AvatarGroupPolicy.new(archived, user: Client.new).destroy?
    assert_not AvatarGroupPolicy.new(Object.new, user: Client.new).show?
  end

  test "relation scope keeps only the selected account's app groups" do
    own = AvatarGroup.create!(account_surface: "app", account_public_id: "account-1", name: "Own", state: "active")
    AvatarGroup.create!(account_surface: "app", account_public_id: "account-2", name: "Other", state: "active")
    AvatarGroup.create!(account_surface: "org", account_public_id: "account-1", name: "Surface", state: "active")

    scoped = AvatarGroupPolicy.new(AvatarGroup, user: Client.new).apply_scope(
      AvatarGroup.all,
      type: :active_record_relation,
    )

    assert_equal [own.id], scoped.pluck(:id)
  end

  test "relation scope is empty for a non-client or without a selected account" do
    AvatarGroup.create!(account_surface: "app", account_public_id: "account-1", name: "Own", state: "active")

    assert_empty AvatarGroupPolicy.new(AvatarGroup, user: Visitor.new).apply_scope(
      AvatarGroup.all,
      type: :active_record_relation,
    )

    Actor.install_context!(selection: Actor::SelectedContext.new(account_public_id: nil))

    assert_empty AvatarGroupPolicy.new(AvatarGroup, user: Client.new).apply_scope(
      AvatarGroup.all,
      type: :active_record_relation,
    )
  end
end
