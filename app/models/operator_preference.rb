# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preferences
# Database name: org_principal
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
#  page_size       :string           default("20"), not null
#  performant      :boolean          default(FALSE), not null
#  region          :string           default("jp"), not null
#  targetable      :boolean          default(FALSE), not null
#  theme           :string           default("sy"), not null
#  time_format     :string           default("hour_24"), not null
#  timezone        :string           default("Asia/Tokyo"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  public_id       :string(21)
#  staff_id        :bigint           not null
#
# Indexes
#
#  index_operator_preferences_on_public_id  (public_id) UNIQUE
#  index_operator_preferences_on_staff_id   (staff_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#
class OperatorPreference < OrgPrincipalRecord
  include ::PublicId
  include ::PreferenceExplicitFields

  belongs_to :staff, inverse_of: :staff_preference, class_name: "Operator"

  has_one :staff_preference_language, class_name: "OperatorPreferenceLanguage", foreign_key: :preference_id,
                                      inverse_of: :preference,
                                      dependent: :destroy
  has_one :staff_preference_timezone, class_name: "OperatorPreferenceTimezone", foreign_key: :preference_id,
                                      inverse_of: :preference,
                                      dependent: :destroy
  has_one :staff_preference_region, class_name: "OperatorPreferenceRegion", foreign_key: :preference_id,
                                    inverse_of: :preference,
                                    dependent: :destroy
  has_one :staff_preference_theme, class_name: "OperatorPreferenceTheme", foreign_key: :preference_id,
                                   inverse_of: :preference,
                                   dependent: :destroy
  has_one :operator_preference_currency,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_date_format,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_time_format,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_motion,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_density,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_page_size,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_adult_content_gate,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy

  validates :staff_id, uniqueness: true
  validates :consented, inclusion: { in: [true, false] }
  validates :functional, inclusion: { in: [true, false] }
  validates :performant, inclusion: { in: [true, false] }
  validates :targetable, inclusion: { in: [true, false] }
  after_initialize :set_defaults

  def adult_content_gate
    operator_preference_adult_content_gate&.option&.name || "nothing"
  end

  private

  # New records get explicit non-consent defaults so a nil never reaches a
  # boolean consent column.
  def set_defaults
    return unless new_record?

    self.consented = false if consented.nil?
    self.functional = false if functional.nil?
    self.performant = false if performant.nil?
    self.targetable = false if targetable.nil?
  end
end
