# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preferences
# Database name: com_principal
#
#  id              :bigint           not null, primary key
#  consent_version :uuid
#  consented       :boolean          default(FALSE), not null
#  consented_at    :datetime
#  currency        :string           default("jpy"), not null
#  date_format     :string           default("iso"), not null
#  density         :string           default("standard"), not null
#  functional      :boolean          default(FALSE), not null
#  language        :string           default("ja"), not null
#  motion          :string           default("standard"), not null
#  page_size       :string           default("infinity"), not null
#  performant      :boolean          default(FALSE), not null
#  region          :string           default("jp"), not null
#  targetable      :boolean          default(FALSE), not null
#  theme           :string           default("sy"), not null
#  time_format     :string           default("24"), not null
#  timezone        :string           default("Asia/Tokyo"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  public_id       :string(21)
#  visitor_id      :bigint           not null
#
# Indexes
#
#  index_visitor_preferences_on_public_id   (public_id) UNIQUE
#  index_visitor_preferences_on_visitor_id  (visitor_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (visitor_id => visitors.id)
#
require "test_helper"

class VisitorPreferenceTest < ActiveSupport::TestCase
  setup do
    Prosopite.pause do
      VisitorMfaLevel.ensure_defaults!
      VisitorMfaStatus.ensure_defaults!
      VisitorStatus.ensure_defaults!
      VisitorVisibility.ensure_defaults!
      VisitorPreferenceLanguageOption.ensure_defaults!
      VisitorPreferenceTimezoneOption.ensure_defaults!
      VisitorPreferenceRegionOption.ensure_defaults!
      VisitorPreferenceThemeOption.ensure_defaults!
      VisitorPreferenceCurrencyOption.ensure_defaults!
      VisitorPreferenceDateFormatOption.ensure_defaults!
      VisitorPreferenceTimeFormatOption.ensure_defaults!
      VisitorPreferenceMotionOption.ensure_defaults!
      VisitorPreferenceDensityOption.ensure_defaults!
      VisitorPreferencePageSizeOption.ensure_defaults!
    end
  end

  test "belongs to visitor and keeps defaults" do
    visitor = Visitor.create!
    preference = VisitorPreference.create!(visitor: visitor)

    assert_equal visitor, preference.visitor
    assert_not preference.consented
    assert_equal "ja", preference.language
    assert_equal "jp", preference.region
    assert_equal "Asia/Tokyo", preference.timezone
    assert_equal "sy", preference.theme
  end

  test "generates public_id on create" do
    preference = VisitorPreference.create!(visitor: Visitor.create!)

    assert_not_nil preference.public_id
    assert_equal 21, preference.public_id.length
  end

  test "does not overwrite existing public_id" do
    preference = VisitorPreference.create!(visitor: Visitor.create!, public_id: "visitor_pref_custom")

    assert_equal "visitor_pref_custom", preference.public_id
  end

  test "loading an existing preference preserves stored defaults" do
    preference = VisitorPreference.create!(visitor: Visitor.create!)
    preference.update!(
      consented: true,
      functional: true,
      performant: true,
      targetable: true,
    )

    loaded = VisitorPreference.find(preference.id)

    assert loaded.consented
    assert loaded.functional
    assert loaded.performant
    assert loaded.targetable
  end

  test "child preference records default to expected option ids" do
    preference = VisitorPreference.create!(visitor: Visitor.create!)

    language = VisitorPreferenceLanguage.create!(preference: preference)
    timezone = VisitorPreferenceTimezone.create!(preference: preference)
    region = VisitorPreferenceRegion.create!(preference: preference)
    theme = VisitorPreferenceTheme.create!(preference: preference)
    currency = VisitorPreferenceCurrency.create!(preference: preference)
    date_format = VisitorPreferenceDateFormat.create!(preference: preference)
    time_format = VisitorPreferenceTimeFormat.create!(preference: preference)
    motion = VisitorPreferenceMotion.create!(preference: preference)
    density = VisitorPreferenceDensity.create!(preference: preference)
    page_size = VisitorPreferencePageSize.create!(preference: preference)

    assert_equal VisitorPreferenceLanguageOption::JA, language.option_id
    assert_equal VisitorPreferenceTimezoneOption::ASIA_TOKYO, timezone.option_id
    assert_equal VisitorPreferenceRegionOption::JP, region.option_id
    assert_equal VisitorPreferenceThemeOption::SYSTEM, theme.option_id
    assert_equal VisitorPreferenceCurrencyOption::JPY, currency.option_id
    assert_equal VisitorPreferenceDateFormatOption::ISO, date_format.option_id
    assert_equal VisitorPreferenceTimeFormatOption::HOUR_24, time_format.option_id
    assert_equal VisitorPreferenceMotionOption::STANDARD, motion.option_id
    assert_equal VisitorPreferenceDensityOption::STANDARD, density.option_id
    assert_equal VisitorPreferencePageSizeOption::PER_20, page_size.option_id
    assert_equal "infinity", VisitorPreferencePageSizeOption.new(id: VisitorPreferencePageSizeOption::PER_INFINITY).name
  end

  test "adult_content_gate returns nothing when no gate is set" do
    assert_equal "nothing", VisitorPreference.new.adult_content_gate
  end

  test "adult_content_gate returns the gate option name when a gate is set" do
    preference = VisitorPreference.new
    preference.build_visitor_preference_adult_content_gate(
      option: VisitorPreferenceAdultContentGateOption.new(id: VisitorPreferenceAdultContentGateOption::APPROVED),
    )

    assert_equal "approved", preference.adult_content_gate
  end
end
