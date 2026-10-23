# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceWritePolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "shared preference policies allow token-scoped updates without an actor" do
    # Shared preferences are login-independent surface state; signed preference tokens authorize
    # these writes before an actor-local preference exists.
    assert_predicate AppPreferencePolicy.new(AppPreference.new, user: nil), :update?
    assert_predicate OrgPreferencePolicy.new(OrgPreference.new, user: nil), :update?
    assert_predicate ComPreferencePolicy.new(ComPreference.new, user: nil), :update?
  end

  test "AppPreferencePolicy allows update when record is the class" do
    assert_predicate AppPreferencePolicy.new(AppPreference, user: nil), :update?
  end

  test "AppPreferencePolicy allows update when record is an instance" do
    assert_predicate AppPreferencePolicy.new(AppPreference.new, user: nil), :update?
  end

  test "AppPreferencePolicy denies non-AppPreference record" do
    assert_not AppPreferencePolicy.new(String.new, user: nil).update?
  end

  test "AppPreferencePolicy denies index by default" do
    assert_not AppPreferencePolicy.new(AppPreference.new, user: nil).index?
  end

  test "AppPreferencePolicy denies show by default" do
    assert_not AppPreferencePolicy.new(AppPreference.new, user: nil).show?
  end

  test "AppPreferencePolicy denies create by default" do
    assert_not AppPreferencePolicy.new(AppPreference.new, user: nil).create?
  end

  test "AppPreferencePolicy denies destroy by default" do
    assert_not AppPreferencePolicy.new(AppPreference.new, user: nil).destroy?
  end

  test "ComPreferencePolicy allows update when record is the class" do
    assert_predicate ComPreferencePolicy.new(ComPreference, user: nil), :update?
  end

  test "ComPreferencePolicy allows update when record is an instance" do
    assert_predicate ComPreferencePolicy.new(ComPreference.new, user: nil), :update?
  end

  test "ComPreferencePolicy denies non-ComPreference record" do
    assert_not ComPreferencePolicy.new(String.new, user: nil).update?
  end

  test "OrgPreferencePolicy allows update when record is the class" do
    assert_predicate OrgPreferencePolicy.new(OrgPreference, user: nil), :update?
  end

  test "OrgPreferencePolicy allows update when record is an instance" do
    assert_predicate OrgPreferencePolicy.new(OrgPreference.new, user: nil), :update?
  end

  test "OrgPreferencePolicy denies non-OrgPreference record" do
    assert_not OrgPreferencePolicy.new(String.new, user: nil).update?
  end

  test "client preference policy only allows the owning client" do
    owner = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 10)
    other = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 20)
    preference = ClientPreference.new(user_id: owner.id)

    assert_predicate ClientPreferencePolicy.new(preference, user: owner), :update?
    assert_not ClientPreferencePolicy.new(preference, user: other).update?
    assert_not ClientPreferencePolicy.new(preference, user: nil).update?
  end

  test "client preference policy denies non-Client user" do
    visitor = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 10)
    preference = ClientPreference.new(user_id: visitor.id)

    assert_not ClientPreferencePolicy.new(preference, user: visitor).update?
  end

  test "client preference policy denies non-ClientPreference record" do
    client = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 10)

    assert_not ClientPreferencePolicy.new(String.new, user: client).update?
  end

  test "operator preference policy only allows the owning operator" do
    owner = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 10)
    other = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 20)
    preference = OperatorPreference.new(staff_id: owner.id)

    assert_predicate OperatorPreferencePolicy.new(preference, user: owner), :update?
    assert_not OperatorPreferencePolicy.new(preference, user: other).update?
    assert_not OperatorPreferencePolicy.new(preference, user: nil).update?
  end

  test "operator preference policy denies non-Operator user" do
    client = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 10)
    preference = OperatorPreference.new(staff_id: client.id)

    assert_not OperatorPreferencePolicy.new(preference, user: client).update?
  end

  test "operator preference policy denies non-OperatorPreference record" do
    operator = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 10)

    assert_not OperatorPreferencePolicy.new(String.new, user: operator).update?
  end

  test "visitor preference policy only allows the owning visitor" do
    owner = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 10)
    other = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 20)
    preference = VisitorPreference.new(visitor_id: owner.id)

    assert_predicate VisitorPreferencePolicy.new(preference, user: owner), :update?
    assert_not VisitorPreferencePolicy.new(preference, user: other).update?
    assert_not VisitorPreferencePolicy.new(preference, user: nil).update?
  end

  test "visitor preference policy denies non-Visitor user" do
    client = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 10)
    preference = VisitorPreference.new(visitor_id: client.id)

    assert_not VisitorPreferencePolicy.new(preference, user: client).update?
  end

  test "visitor preference policy denies non-VisitorPreference record" do
    visitor = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 10)

    assert_not VisitorPreferencePolicy.new(String.new, user: visitor).update?
  end
end
