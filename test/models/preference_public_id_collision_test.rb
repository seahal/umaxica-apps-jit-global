# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferencePublicIdCollisionTest < ActiveSupport::TestCase
  REALM_CASES = [
    [ClientPreference, :user, -> { Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL) }],
    [VisitorPreference, :visitor, -> { Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL) }],
    [OperatorPreference, :staff, -> { Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED) }],
  ].freeze

  test "retries a generated public_id collision for each realm preference" do
    REALM_CASES.each do |preference_class, owner_key, owner_factory|
      first_owner = owner_factory.call
      second_owner = owner_factory.call
      existing = preference_class.create!({ owner_key => first_owner }.merge(public_id: "a" * 21))
      generated = [existing.public_id, "b" * 21]

      PublicId.stub(:generate, -> { generated.shift }) do
        replacement = preference_class.create!(owner_key => second_owner)

        assert_equal "b" * 21, replacement.public_id, preference_class.name
      end
    end
  end

  test "retries a database collision when validation is bypassed" do
    REALM_CASES.each do |preference_class, owner_key, owner_factory|
      existing_owner = owner_factory.call
      replacement_owner = owner_factory.call
      existing = preference_class.create!({ owner_key => existing_owner }.merge(public_id: "c" * 21))
      generated = [existing.public_id, "d" * 21]

      PublicId.stub(:generate, -> { generated.shift }) do
        replacement = preference_class.new(owner_key => replacement_owner)
        replacement.save!(validate: false)

        assert_equal "d" * 21, replacement.public_id, preference_class.name
      end
    end
  end

  test "does not regenerate a caller-supplied public_id after a database collision" do
    REALM_CASES.each do |preference_class, owner_key, owner_factory|
      existing_owner = owner_factory.call
      replacement_owner = owner_factory.call
      existing = preference_class.create!({ owner_key => existing_owner }.merge(public_id: "e" * 21))
      generated = ["f" * 21]

      PublicId.stub(:generate, -> { generated.shift }) do
        replacement = preference_class.new(
          { owner_key => replacement_owner }.merge(public_id: existing.public_id),
        )

        assert_raises(ActiveRecord::RecordNotUnique) { replacement.save!(validate: false) }
        assert_equal existing.public_id, replacement.public_id
        assert_equal ["f" * 21], generated
      end
    end
  end

  test "rejects persisted public_id changes for each realm preference" do
    REALM_CASES.each do |preference_class, owner_key, owner_factory|
      preference = preference_class.create!(owner_key => owner_factory.call)
      original = preference.public_id

      preference.public_id = "g" * 21

      assert_raises(ActiveRecord::RecordInvalid) { preference.save! }
      assert_equal original, preference.reload.public_id
    end
  end
end
