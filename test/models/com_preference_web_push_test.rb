# typed: false
# frozen_string_literal: true

require "test_helper"

class ComPreferenceWebPushTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    [ComPreferenceStatus,
     ComPreferenceWebPushOption,].each(&:ensure_defaults!)
    @preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
  end

  test "defaults to disabled and accepts the two closed options" do
    record = ComPreferenceWebPush.create!(preference: @preference)

    assert_equal ComPreferenceWebPushOption::DISABLED, record.option_id
    assert_equal "disabled", ComPreferenceWebPushOption.find(record.option_id).name
    record.update!(option_id: ComPreferenceWebPushOption::ENABLED)

    assert_equal "enabled", ComPreferenceWebPushOption.find(record.reload.option_id).name
  end

  test "rejects an unsupported option and a second record for the same preference" do
    ComPreferenceWebPush.create!(preference: @preference)
    duplicate = ComPreferenceWebPush.new(preference: @preference, option_id: ComPreferenceWebPushOption::ENABLED)
    invalid_option = ComPreferenceWebPush.new(preference: @preference, option_id: 2)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:preference_id, :taken)
    assert_not invalid_option.valid?
    assert invalid_option.errors.of_kind?(:option_id, :inclusion)
  end
end
