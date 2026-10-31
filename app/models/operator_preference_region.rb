# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_regions
# Database name: org_principal
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_operator_preference_regions_on_option_id      (option_id)
#  index_operator_preference_regions_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_staff_preference_regions_on_option_id      (option_id => operator_preference_region_options.id)
#  fk_staff_preference_regions_on_preference_id  (preference_id => operator_preferences.id)
#
class OperatorPreferenceRegion < OrgPrincipalRecord
  belongs_to :preference, class_name: "OperatorPreference", inverse_of: :operator_preference_region
  belongs_to :option,
             class_name: "OperatorPreferenceRegionOption",
             inverse_of: :operator_preference_regions
  validates :preference_id, uniqueness: true
  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= OperatorPreferenceRegionOption::JP
  end
end
