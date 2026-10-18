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
  test "accepts integer ids" do
    kind = ClientTokenKind.new(id: 99)

    assert_predicate kind, :valid?
  end

  test "constants are defined" do
    assert_equal 11, ClientTokenKind::BROWSER_WEB
    assert_equal 12, ClientTokenKind::CLIENT_IOS
    assert_equal 13, ClientTokenKind::CLIENT_ANDROID
  end

  test "defaults are defined" do
    assert_equal [11, 12, 13], ClientTokenKind::DEFAULTS
  end

  test "has many client_tokens" do
    assert_equal :has_many, ClientTokenKind.reflect_on_association(:client_tokens).macro
  end
end
