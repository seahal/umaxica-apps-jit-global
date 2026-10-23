# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ClientPasskeyPolicyTest < ActiveSupport::TestCase
  def test_index_denied_for_nil_user
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: nil)

    assert_not policy.index?
  end

  def test_index_allowed_for_authenticated_user
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: user)

    assert_predicate policy, :index?
  end

  def test_show_denied_for_nil_user
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: nil)

    assert_not policy.show?
  end

  def test_show_allowed_for_owner
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    passkey = ClientPasskey.new(user_id: user.id)
    policy = ClientPasskeyPolicy.new(passkey, user: user)

    assert_predicate policy, :show?
  end

  def test_show_denied_for_non_owner
    owner = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    other = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 2)
    passkey = ClientPasskey.new(user_id: owner.id)
    policy = ClientPasskeyPolicy.new(passkey, user: other)

    assert_not policy.show?
  end

  def test_create_denied_for_nil_user
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: nil)

    assert_not policy.create?
  end

  def test_create_allowed_for_authenticated_user
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: user)

    assert_predicate policy, :create?
  end

  def test_new_delegates_to_create
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: user)

    assert_predicate policy, :new?
  end

  def test_new_denied_for_nil_user
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: nil)

    assert_not policy.new?
  end

  def test_update_denied_for_nil_user
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: nil)

    assert_not policy.update?
  end

  def test_update_allowed_for_owner
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    passkey = ClientPasskey.new(user_id: user.id)
    policy = ClientPasskeyPolicy.new(passkey, user: user)

    assert_predicate policy, :update?
  end

  def test_update_denied_for_non_owner
    owner = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    other = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 2)
    passkey = ClientPasskey.new(user_id: owner.id)
    policy = ClientPasskeyPolicy.new(passkey, user: other)

    assert_not policy.update?
  end

  def test_edit_delegates_to_update
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    passkey = ClientPasskey.new(user_id: user.id)
    policy = ClientPasskeyPolicy.new(passkey, user: user)

    assert_predicate policy, :edit?
  end

  def test_edit_denied_for_nil_user
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: nil)

    assert_not policy.edit?
  end

  def test_destroy_denied_for_nil_user
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: nil)

    assert_not policy.destroy?
  end

  def test_destroy_allowed_for_owner
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    passkey = ClientPasskey.new(user_id: user.id)
    policy = ClientPasskeyPolicy.new(passkey, user: user)

    assert_predicate policy, :destroy?
  end

  def test_destroy_denied_for_non_owner
    owner = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    other = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 2)
    passkey = ClientPasskey.new(user_id: owner.id)
    policy = ClientPasskeyPolicy.new(passkey, user: other)

    assert_not policy.destroy?
  end
end
