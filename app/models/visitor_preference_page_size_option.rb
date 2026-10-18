# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_page_size_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorPreferencePageSizeOption < ComPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  PER_10 = 1
  PER_20 = 2
  PER_50 = 3
  PER_100 = 4
  PER_INFINITY = 5

  DEFAULTS = [NOTHING, PER_10, PER_20, PER_50, PER_100, PER_INFINITY].freeze

  has_many :visitor_preference_page_sizes,
           class_name: "VisitorPreferencePageSize",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when 1 then "10"
    when 2 then "20"
    when 3 then "50"
    when 4 then "100"
    when 5 then "infinity"
    end
  end
end
