# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_density_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorPreferenceDensityOption < ComPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  STANDARD = 1
  COMPACT = 2

  DEFAULTS = [NOTHING, STANDARD, COMPACT].freeze

  has_many :visitor_preference_densities,
           class_name: "VisitorPreferenceDensity",
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
