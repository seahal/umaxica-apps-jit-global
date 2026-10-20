# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_token_kinds
# Database name: op_base_org
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorTokenKindTest < ActiveSupport::TestCase
  test "accepts integer ids" do
    kind = OperatorTokenKind.new(id: 99)

    assert_predicate kind, :valid?
  end

  test "constants are defined" do
    assert_equal 1, OperatorTokenKind::BROWSER_WEB
    assert_equal 2, OperatorTokenKind::CLIENT_IOS
    assert_equal 3, OperatorTokenKind::CLIENT_ANDROID
  end

  test "defaults are defined" do
    assert_equal [1, 2, 3], OperatorTokenKind::DEFAULTS
  end

  test "has many staff_tokens" do
    assert_equal :has_many, OperatorTokenKind.reflect_on_association(:staff_tokens).macro
  end

  test "token kind finds its existing operator tokens through the retained staff foreign key" do
    kind = OperatorTokenKind.includes(:staff_tokens).find(OperatorTokenKind::BROWSER_WEB)

    assert_includes kind.staff_tokens.to_a, operator_tokens(:one)
    assert_empty OperatorTokenKind.includes(:staff_tokens).find(OperatorTokenKind::CLIENT_IOS).staff_tokens.to_a
  end

  test "token kind refuses destruction while operator tokens reference it" do
    kind = OperatorTokenKind.find(OperatorTokenKind::BROWSER_WEB)

    assert_not kind.destroy
    assert kind.errors.of_kind?(:base, :"restrict_dependent_destroy.has_many")
    assert_predicate kind.reload, :persisted?
    assert_predicate operator_tokens(:one).reload, :persisted?
  end

  test "database refuses deletion of an operator token kind still in use" do
    kind = OperatorTokenKind.find(OperatorTokenKind::BROWSER_WEB)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        OperatorTokenKind.transaction(requires_new: true) { kind.delete }
      end
    assert_instance_of PG::RestrictViolation, error.cause
    assert_predicate kind.reload, :persisted?
    assert_predicate operator_tokens(:one).reload, :persisted?
  end
end
