# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ClientTokenPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def setup
    @user = nil
    @record = nil
    @policy = ClientTokenPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
  end

  # index? gates the session listing to the owning actor type (Client).
  def test_index_allows_client
    assert_predicate ClientTokenPolicy.new(nil, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)),
                     :index?
  end

  def test_index_denies_other_actor_types
    assert_not ClientTokenPolicy.new(nil, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)).index?
    assert_not ClientTokenPolicy.new(nil, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)).index?
  end

  def test_destroy_allows_owner_client_token
    client = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 123)
    token = ClientToken.new(user_id: client.id)

    assert_predicate ClientTokenPolicy.new(token, user: client), :destroy?
  end

  def test_destroy_denies_other_client_token
    client = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 123)
    token = ClientToken.new(user_id: 456)

    assert_not ClientTokenPolicy.new(token, user: client).destroy?
  end

  def test_destroy_denies_other_actor_types
    token = ClientToken.new(user_id: 123)

    assert_not ClientTokenPolicy.new(
      token,
      user: Operator.new(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        id: 123,
      ),
    ).destroy?
    assert_not ClientTokenPolicy.new(
      token,
      user: Visitor.new(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 123,
      ),
    ).destroy?
  end

  def test_revoke_others_allows_client_token_class_for_client
    assert_predicate ClientTokenPolicy.new(ClientToken, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)),
                     :revoke_others?
  end

  def test_revoke_others_denies_non_clients_and_instances
    assert_not ClientTokenPolicy.new(ClientToken, user: Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)).revoke_others?
    assert_not ClientTokenPolicy.new(ClientToken, user: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL)).revoke_others?
    assert_not ClientTokenPolicy.new(ClientToken.new, user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)).revoke_others?
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
end
