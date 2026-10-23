# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ClientEmailPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = ClientEmailPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
  end

  # index? gates the email listing to the owning actor type (Client).
  def test_index_allows_client
    assert_predicate ClientEmailPolicy.new(nil, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)),
                     :index?
  end

  def test_index_denies_other_actor_types
    assert_not ClientEmailPolicy.new(nil, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)).index?
    assert_not ClientEmailPolicy.new(nil, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)).index?
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

  # create? gates registration (fresh record) to the owning actor type.
  def test_create_allows_client
    assert_predicate ClientEmailPolicy.new(nil, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)),
                     :create?
    assert_predicate ClientEmailPolicy.new(nil, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)),
                     :new?
  end

  def test_create_denies_other_actor_types
    assert_not ClientEmailPolicy.new(nil, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)).create?
    assert_not ClientEmailPolicy.new(nil, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)).create?
  end

  # update?/destroy? require ownership of the specific record (record.user_id == client.id).
  def test_update_and_destroy_allow_owner
    owner = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    record = ClientEmail.new(user_id: 1)

    assert_predicate ClientEmailPolicy.new(record, user: owner), :update?
    assert_predicate ClientEmailPolicy.new(record, user: owner), :edit?
    assert_predicate ClientEmailPolicy.new(record, user: owner), :destroy?
  end

  def test_update_and_destroy_deny_non_owner
    owner = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    record = ClientEmail.new(user_id: 2)

    assert_not ClientEmailPolicy.new(record, user: owner).update?
    assert_not ClientEmailPolicy.new(record, user: owner).destroy?
  end
end
