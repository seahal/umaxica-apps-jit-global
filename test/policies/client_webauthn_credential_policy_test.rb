# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ClientWebauthnCredentialPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = ClientWebauthnCredentialPolicy.new(@record, user: @user)
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

  def test_record_owner_returns_false_when_user_does_not_own_record
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    record = ClientPasskey.new(user_id: user.id + 1)
    policy = ClientWebauthnCredentialPolicy.new(record, user: user)

    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
  end
end
