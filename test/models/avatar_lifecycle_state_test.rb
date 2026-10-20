# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarLifecycleStateTest < ActiveSupport::TestCase
  test "seed states exist" do
    assert_equal %w(active suspended archived banned deleted), AvatarLifecycleState.order(:sort_order).pluck(:key)
  end

  test "key is unique" do
    duplicate = AvatarLifecycleState.new(
      key: "active",
      title: "Duplicate",
      can_create_content: true,
      visible_by_default: true,
      editable_by_owner: true,
      restorable_by_owner: false,
      followable: true,
      group_attachable: true,
      discoverable: true,
      moderation_visible: true,
      terminal: false,
      sort_order: 99,
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :key
  end

  test "restricted states cannot create content or be discovered" do
    AvatarLifecycleState.where(key: %w(suspended archived banned deleted)).find_each do |state|
      assert_not state.can_create_content, "#{state.key} must not create content"
      assert_not state.discoverable, "#{state.key} must not be discoverable"
    end
  end

  test "banned and deleted are not owner restorable" do
    AvatarLifecycleState.where(key: %w(banned deleted)).find_each do |state|
      assert_not state.restorable_by_owner, "#{state.key} must not be owner restorable"
    end
  end

  test "deleted is terminal" do
    assert_predicate avatar_lifecycle_states(:deleted), :terminal
  end
  BOOLEAN_FIELDS = %i(
    can_create_content visible_by_default editable_by_owner restorable_by_owner followable
    group_attachable discoverable moderation_visible terminal
  ).freeze

  BOOLEAN_FIELDS.each do |field|
    test "#{field} preserves both boolean values and database null rejection" do
      state = AvatarLifecycleState.new(
        key: "consistency-probe", title: "Consistency probe", sort_order: 999,
        can_create_content: false, visible_by_default: false, editable_by_owner: false,
        restorable_by_owner: false, followable: false, group_attachable: false,
        discoverable: false, moderation_visible: false, terminal: false,
      )
      state.save!

      assert_same false, state.reload[field]
      state.update!(field => true)

      assert_same true, state.reload[field]
      state[field] = nil
      error =
        assert_raises(ActiveRecord::NotNullViolation) do
          AvatarLifecycleState.transaction(requires_new: true) { state.save!(validate: false) }
        end
      assert_equal field.to_s, error.cause.result.error_field(PG::Result::PG_DIAG_COLUMN_NAME)
      assert_same true, state.reload[field]
    end

    test "#{field} rejects nil and empty input before creation" do
      [nil, ""].each do |value|
        state = AvatarLifecycleState.new(
          key: "consistency-probe", title: "Consistency probe", sort_order: 999,
          can_create_content: false, visible_by_default: false, editable_by_owner: false,
          restorable_by_owner: false, followable: false, group_attachable: false,
          discoverable: false, moderation_visible: false, terminal: false,
        )
        state[field] = value

        assert_not state.valid?
        assert_not_empty state.errors[field]
        assert_raises(ActiveRecord::RecordInvalid) { state.save! }
        assert_predicate state, :new_record?
      end
    end
  end
end
