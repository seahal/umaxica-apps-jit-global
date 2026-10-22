# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_token_kinds
# Database name: op_base_com
#
#  id :bigint           not null, primary key
#

require "test_helper"

class VisitorTokenKindTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 1, VisitorTokenKind::BROWSER_WEB
    assert_equal 2, VisitorTokenKind::CLIENT_IOS
    assert_equal 3, VisitorTokenKind::CLIENT_ANDROID
  end

  test "defaults are defined" do
    assert_equal [1, 2, 3], VisitorTokenKind::DEFAULTS
  end

  test "has many visitor_tokens" do
    assert_equal :has_many, VisitorTokenKind.reflect_on_association(:visitor_tokens).macro
  end
end
