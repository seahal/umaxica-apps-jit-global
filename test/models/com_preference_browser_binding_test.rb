# typed: false
# frozen_string_literal: true

require "test_helper"

class ComPreferenceBrowserBindingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    [ComPreferenceStatus].each(&:ensure_defaults!)
    @preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
  end

  test "the same digest can bind different preferences but not twice to one preference" do
    digest = "a" * 64
    ComPreferenceBrowserBinding.create!(preference: @preference, digest: digest)
    other = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    another_binding = ComPreferenceBrowserBinding.create!(preference: other, digest: digest)
    duplicate = ComPreferenceBrowserBinding.new(preference: @preference, digest: "b" * 64)

    assert_predicate another_binding, :persisted?
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:preference_id, :taken)
  end

  test "requires a lowercase SHA-256 hex digest of exactly 64 characters" do
    [nil, "", "a" * 63, "a" * 65, "g" * 64, "A" * 64].each do |digest|
      assert_not ComPreferenceBrowserBinding.new(preference: @preference, digest: digest).valid?
    end

    assert_predicate ComPreferenceBrowserBinding.new(preference: @preference, digest: "a" * 64), :valid?
  end
end
