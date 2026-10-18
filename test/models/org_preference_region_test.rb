# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: org_preference_regions
# Database name: org_setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_org_preference_regions_on_option_id      (option_id)
#  index_org_preference_regions_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_org_preference_regions_on_option_id  (option_id => org_preference_region_options.id)
#  fk_rails_...                            (preference_id => org_preferences.id)
#

require "test_helper"

class OrgPreferenceRegionTest < ActiveSupport::TestCase
  setup do
    OrgPreferenceStatus.find_or_create_by!(id: OrgPreferenceStatus::NOTHING)
    @preference = OrgPreference.create!(status_id: OrgPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    region = OrgPreferenceRegion.new

    assert_not region.valid?
    assert_includes region.errors[:preference], I18n.t("errors.messages.required")
  end

  test "can be created with preference and option" do
    option = org_preference_region_options(:jp)
    region = OrgPreferenceRegion.create!(preference: @preference, option: option)

    assert_not_nil region.id
    assert_equal @preference, region.preference
    assert_equal option, region.option
  end

  test "sets default option_id on create" do
    region = OrgPreferenceRegion.create!(preference: @preference)

    assert_equal OrgPreferenceRegionOption::JP, region.option_id
  end
end
