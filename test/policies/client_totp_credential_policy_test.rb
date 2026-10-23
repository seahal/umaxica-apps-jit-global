# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ClientTotpCredentialPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = ClientTotpCredentialPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
  end

  def test_show
    assert_not @policy.show?
  end

  def test_create
    assert_not @policy.create?
  end

  def test_new
    assert_not @policy.new?
  end

  def test_update
    assert_not @policy.update?
  end

  def test_edit
    assert_not @policy.edit?
  end

  def test_destroy
    assert_not @policy.destroy?
  end

  # index?/new?/create? allow any client actor (registration does not yet have a record).
  def test_index_and_create_allow_client
    policy = ClientTotpCredentialPolicy.new(
      ClientTotpCredential.new,
      user: Client.new(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 1,
      ),
    )

    assert_predicate policy, :index?
    assert_predicate policy, :create?
    assert_predicate policy, :new?
  end

  def test_index_and_create_deny_other_actor_types
    policy = ClientTotpCredentialPolicy.new(
      ClientTotpCredential.new,
      user: Operator.new(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        id: 1,
      ),
    )

    assert_not policy.index?
    assert_not policy.create?
  end

  # Per-record actions require ownership (record.user_id == user.id).
  def test_owner_may_manage_own_record
    owner = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    record = ClientTotpCredential.new(user_id: owner.id)
    policy = ClientTotpCredentialPolicy.new(record, user: owner)

    assert_predicate policy, :show?
    assert_predicate policy, :update?
    assert_predicate policy, :edit?
    assert_predicate policy, :destroy?
  end

  def test_non_owner_may_not_manage_record
    record = ClientTotpCredential.new(user_id: 1)
    policy = ClientTotpCredentialPolicy.new(
      record,
      user: Client.new(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 2,
      ),
    )

    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
  end
end
