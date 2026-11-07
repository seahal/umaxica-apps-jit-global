# frozen_string_literal: true

require "test_helper"

class RpBaseSessionSelectionValidationTest < ActiveSupport::TestCase
  test "APP selection rejects account public ids longer than its database column" do
    selection = RpBaseAppSessionSelection.new(
      account_public_id: "a" * 22,
      organization_public_id: "b" * 21,
      organization_unit_public_id: "c" * 21,
      avatar_public_id: "d" * 21,
      selected_at: Time.current,
    )

    assert_not selection.valid?
    assert_includes selection.errors.details.fetch(:account_public_id), error: :too_long, count: 21
  end

  test "ORG selection rejects account public ids longer than its database column" do
    selection = RpBaseOrgSessionSelection.new(
      account_public_id: "a" * 22,
      organization_public_id: "b" * 21,
      organization_unit_public_id: "c" * 21,
      selected_at: Time.current,
    )

    assert_not selection.valid?
    assert_includes selection.errors.details.fetch(:account_public_id), error: :too_long, count: 21
  end
end
