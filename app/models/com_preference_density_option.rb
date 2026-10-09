# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_density_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
class ComPreferenceDensityOption < ComSettingRecord
  include ReferenceRecord

  NOTHING = 0
  STANDARD = 1
  COMPACT = 2

  DEFAULTS = [NOTHING, STANDARD, COMPACT].freeze

  has_many :com_preference_densities,
           class_name: "ComPreferenceDensity",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when 1 then "standard"
    when 2 then "compact"
    end
  end
end
