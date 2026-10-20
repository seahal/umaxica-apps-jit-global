# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_region_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
# Indexes
#
#  index_visitor_preference_region_options_on_id  (id) UNIQUE
#
class VisitorPreferenceRegionOption < ComPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  US = 1
  JP = 2

  DEFAULTS = [NOTHING, US, JP].freeze

  has_many :visitor_preference_regions,
           class_name: "VisitorPreferenceRegion",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  # Unique indexes that include the primary key back composite references; checked only for an explicit id.
  validates :id, uniqueness: true, allow_nil: true, if: :will_save_change_to_id?

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when US then "US"
    when JP then "JP"
    end
  end

  self.primary_key = :id
end
