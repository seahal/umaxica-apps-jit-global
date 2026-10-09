# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_currency_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
class AppPreferenceCurrencyOption < AppSettingRecord
  include ReferenceRecord

  NOTHING = 0
  USD = 1
  JPY = 2

  DEFAULTS = [NOTHING, USD, JPY].freeze

  has_many :app_preference_currencies,
           class_name: "AppPreferenceCurrency",
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
