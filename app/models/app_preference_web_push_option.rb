# frozen_string_literal: true

class AppPreferenceWebPushOption < AppSettingRecord
  include ReferenceRecord

  DISABLED = 0
  ENABLED = 1
  DEFAULTS = [DISABLED, ENABLED].freeze

  has_many :app_preference_web_pushes,
           class_name: "AppPreferenceWebPush",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  public

  class << self
    public

    def ensure_defaults!
      insert_missing_fixed_ids!(DEFAULTS)
    end
  end

  def name
    case id
    when DISABLED then "disabled"
    when ENABLED then "enabled"
    else raise ArgumentError, "unsupported app Web Push option id: #{id.inspect}"
    end
  end
end
