# typed: false
# frozen_string_literal: true

require "test_helper"

class PublishingEntryPolicyTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  setup do
    @operator = operators(:one)
    @entry = Publishing::Docs::App::Entry.create!(locale: "ja")
  end

  test "an operator in force may read and write the CMS" do
    policy = PublishingEntryPolicy.new(@entry, user: @operator)

    assert_predicate policy, :index?
    assert_predicate policy, :show?
    assert_predicate policy, :create?
    assert_predicate policy, :update?
    assert_predicate policy, :destroy?
  end

  # A withdrawn operator keeps a valid session until it expires. Publishing with it would put
  # content in front of readers on the authority of an account that is no longer in force.
  test "a withdrawn operator may not read or write the CMS" do
    @operator.withdrawn_at = Time.current
    policy = PublishingEntryPolicy.new(@entry, user: @operator)

    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "an operator whose withdrawal has started may not read or write the CMS" do
    @operator.withdrawal_started_at = Time.current
    policy = PublishingEntryPolicy.new(@entry, user: @operator)

    assert_not policy.show?
    assert_not policy.update?
  end

  # The CMS is a staff surface. An end-user client that reached the policy with a session of its
  # own is not a staff operator, and no answer here may depend on which cell was asked about.
  test "a client is not a staff operator" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    policy = PublishingEntryPolicy.new(@entry, user: client)

    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "an absent actor is denied rather than defaulted" do
    policy = PublishingEntryPolicy.new(@entry, user: nil)

    assert_not policy.index?
    assert_not policy.update?
  end
end
