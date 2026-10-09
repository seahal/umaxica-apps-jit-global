# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_currency_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorPreferenceCurrencyOption < ComPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  USD = 1
  JPY = 2

  DEFAULTS = [NOTHING, USD, JPY].freeze

  has_many :visitor_preference_currencies,
           class_name: "VisitorPreferenceCurrency",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when 1 then "usd"
    when 2 then "jpy"
    end
  end
end
