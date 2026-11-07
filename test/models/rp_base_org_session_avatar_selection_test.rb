# frozen_string_literal: true

require "test_helper"

class RpBaseOrgSessionAvatarSelectionTest < ActiveSupport::TestCase
  test "accepts a 21-character Avatar public ID for a selected actor context" do
    actor_selection = RpBaseOrgSessionSelection.new(
      account_public_id: "a" * 21,
      organization_public_id: "b" * 21,
      organization_unit_public_id: "c" * 21,
      selected_at: Time.current,
    )
    avatar_selection = RpBaseOrgSessionAvatarSelection.new(
      actor_selection:,
      avatar_public_id: "d" * 21,
      selected_at: Time.current,
    )

    assert_predicate avatar_selection, :valid?
  end

  test "rejects an Avatar public ID longer than its database column" do
    actor_selection = RpBaseOrgSessionSelection.new(
      account_public_id: "a" * 21,
      organization_public_id: "b" * 21,
      organization_unit_public_id: "c" * 21,
      selected_at: Time.current,
    )
    avatar_selection = RpBaseOrgSessionAvatarSelection.new(
      actor_selection:,
      avatar_public_id: "d" * 22,
      selected_at: Time.current,
    )

    assert_not avatar_selection.valid?
    assert_includes avatar_selection.errors.details.fetch(:avatar_public_id), error: :too_long, count: 21
  end

  test "rejects a malformed 21-character Avatar public ID" do
    actor_selection = RpBaseOrgSessionSelection.new(
      account_public_id: "a" * 21,
      organization_public_id: "b" * 21,
      organization_unit_public_id: "c" * 21,
      selected_at: Time.current,
    )
    avatar_selection = RpBaseOrgSessionAvatarSelection.new(
      actor_selection:,
      avatar_public_id: "!" * 21,
      selected_at: Time.current,
    )

    assert_not avatar_selection.valid?
    assert avatar_selection.errors.of_kind?(:avatar_public_id, :invalid)
  end
end
