# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_currency_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
class ComPreferenceCurrencyOption < ComSettingRecord
  include ReferenceRecord

  NOTHING = 0
  USD = 1
  JPY = 2

  DEFAULTS = [NOTHING, USD, JPY].freeze

  has_many :com_preference_currencies,
           class_name: "ComPreferenceCurrency",
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
