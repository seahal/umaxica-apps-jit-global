# typed: false
# == Schema Information
#
# Table name: com_preference_cookies
# Database name: com_setting
#
#  id              :bigint           not null, primary key
#  consent_version :uuid
#  consented       :boolean          default(FALSE), not null
#  consented_at    :datetime
#  functional      :boolean          default(FALSE), not null
#  performant      :boolean          default(FALSE), not null
#  targetable      :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  preference_id   :bigint           not null
#
# Indexes
#
#  index_com_preference_cookies_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (preference_id => com_preferences.id)
#

# frozen_string_literal: true

require "test_helper"

class ComPreferenceCookieTest < ActiveSupport::TestCase
  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
    @preference = ComPreference.create!(status_id: ComPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    cookie = ComPreferenceCookie.new(targetable: true)

    assert_not cookie.valid?
    assert cookie.errors.of_kind?(:preference, :blank)
  end

  test "has false as default for all flags" do
    cookie = ComPreferenceCookie.create!(preference: @preference)

    assert_not cookie.targetable
    assert_not cookie.performant
    assert_not cookie.functional
  end

  test "loading an existing cookie preserves stored flags" do
    cookie = ComPreferenceCookie.create!(
      preference: @preference,
      targetable: true,
      performant: true,
      functional: true,
      consented: true,
    )

    loaded = ComPreferenceCookie.find(cookie.id)

    assert loaded.targetable
    assert loaded.performant
    assert loaded.functional
    assert loaded.consented
  end

  %i(targetable performant functional).each do |flag|
    test "raises when #{flag} is nil" do
      cookie = ComPreferenceCookie.new(preference: @preference)
      cookie.assign_attributes(flag => nil)
      assert_raises(ActiveRecord::NotNullViolation) do
        ActiveRecord::Base.logger.silence do
          cookie.save!(validate: false)
        end
      end
    end
  end

  test "persists every boolean flag combination" do
    [false, true].repeated_permutation(3).each do |targetable, performant, functional|
      cookie = ComPreferenceCookie.new(
        preference: @preference,
        targetable: targetable,
        performant: performant,
        functional: functional,
      )

      assert cookie.save, "combo failed: targetable=#{targetable} performant=#{performant} functional=#{functional}"
      cookie.destroy!
    end
  end
end
