# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_regions
# Database name: app_principal
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_client_preference_regions_on_option_id      (option_id)
#  index_client_preference_regions_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_user_preference_regions_on_option_id      (option_id => client_preference_region_options.id)
#  fk_user_preference_regions_on_preference_id  (preference_id => client_preferences.id)
#
class ClientPreferenceRegion < AppPrincipalRecord
  belongs_to :preference, class_name: "ClientPreference", inverse_of: :client_preference_region
  belongs_to :option,
             class_name: "ClientPreferenceRegionOption",
             inverse_of: :client_preference_regions
  validates :preference_id, uniqueness: true
  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= ClientPreferenceRegionOption::JP
  end
end
