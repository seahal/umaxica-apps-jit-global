# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_token_kinds
# Database name: op_base_app
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ClientTokenKindTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 11, ClientTokenKind::BROWSER_WEB
    assert_equal 12, ClientTokenKind::CLIENT_IOS
    assert_equal 13, ClientTokenKind::CLIENT_ANDROID
  end

  test "defaults are defined" do
    assert_equal [11, 12, 13], ClientTokenKind::DEFAULTS
  end

  test "token kind finds its existing client tokens through the retained user foreign key" do
    kind = ClientTokenKind.includes(:client_tokens).find(ClientTokenKind::BROWSER_WEB)

    assert_includes kind.client_tokens.to_a, client_tokens(:one)
    assert_empty ClientTokenKind.includes(:client_tokens).find(ClientTokenKind::CLIENT_IOS).client_tokens.to_a
  end

  test "token kind refuses destruction while client tokens reference it" do
    kind = ClientTokenKind.find(ClientTokenKind::BROWSER_WEB)

    assert_not kind.destroy
    assert kind.errors.of_kind?(:base, :"restrict_dependent_destroy.has_many")
    assert_predicate kind.reload, :persisted?
    assert_predicate client_tokens(:one).reload, :persisted?
  end

  test "database refuses deletion of a client token kind still in use" do
    kind = ClientTokenKind.find(ClientTokenKind::BROWSER_WEB)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        ClientTokenKind.transaction(requires_new: true) { kind.delete }
      end
    assert_instance_of PG::RestrictViolation, error.cause
    assert_predicate kind.reload, :persisted?
    assert_predicate client_tokens(:one).reload, :persisted?
  end
end
