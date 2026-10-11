# typed: false
# frozen_string_literal: true

require "test_helper"

class Actor::SelectedContextTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "NULL context is not selected" do
    assert_not Actor::SelectedContext::NULL.selected?
  end

  test "distinguishes a selected persona from a complete organization context" do
    context = Actor::SelectedContext.new(account_public_id: "persona")

    assert_predicate context, :persona_selected?
    assert_not_predicate context, :organization_context_selected?
    assert_not_predicate context, :selected?
  end

  test "requires the organization unit for the complete organization context" do
    context = Actor::SelectedContext.new(
      account_public_id: "persona",
      collective_public_id: "organization",
    )

    assert_predicate context, :persona_selected?
    assert_not_predicate context, :organization_context_selected?
    assert_not_predicate context, :selected?
  end

  test "keeps selected? as the complete organization context contract" do
    context = Actor::SelectedContext.new(
      account_public_id: "persona",
      collective_public_id: "organization",
      collective_unit_public_id: "unit",
    )

    assert_predicate context, :persona_selected?
    assert_predicate context, :organization_context_selected?
    assert_predicate context, :selected?
  end

  test "equality returns false for non-selected-context objects" do
    context = Actor::SelectedContext.new(account_public_id: "account")

    assert_not_equal context, "not a context"
  end

  test "hash is consistent for equal contexts" do
    context_a = Actor::SelectedContext.new(
      account_public_id: "account",
      collective_public_id: "collective",
      collective_unit_public_id: "unit",
    )
    context_b = Actor::SelectedContext.new(
      account_public_id: "account",
      collective_public_id: "collective",
      collective_unit_public_id: "unit",
    )

    assert_equal context_a, context_b
    assert_equal context_a.hash, context_b.hash
  end
end
