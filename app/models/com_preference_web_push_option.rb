# typed: false
# frozen_string_literal: true

class ComPreferenceWebPushOption < ComSettingRecord
  include ReferenceRecord

  NOTHING = 0
  DISABLED = NOTHING
  ENABLED = 1
  DEFAULTS = [DISABLED, ENABLED].freeze

  has_many :com_preference_web_pushes,
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  public

  def name
    case id
    when DISABLED then "disabled"
    when ENABLED then "enabled"
    end
  end
end
