# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_themes
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
#  index_client_preference_themes_on_option_id      (option_id)
#  index_client_preference_themes_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_user_preference_themes_on_option_id      (option_id => client_preference_theme_options.id)
#  fk_user_preference_themes_on_preference_id  (preference_id => client_preferences.id)
#
class ClientPreferenceTheme < AppPrincipalRecord
  belongs_to :preference, class_name: "ClientPreference", inverse_of: :client_preference_theme
  belongs_to :option,
             class_name: "ClientPreferenceThemeOption",
             inverse_of: :client_preference_themes
  validates :preference_id, uniqueness: true
  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= ClientPreferenceThemeOption::SYSTEM
  end
end
