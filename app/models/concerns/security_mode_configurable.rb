# typed: false
# frozen_string_literal: true

# adr/authentication-security-mode.md: the actor's Security Mode. Only NORMAL (3) and ADVANCED (7)
# are modes; any other value, including a missing one, permits neither authentication nor
# authorization (A3, A5).
module SecurityModeConfigurable
  extend ActiveSupport::Concern

  NORMAL = 3
  ADVANCED = 7
  MODES = [NORMAL, ADVANCED].freeze

  public

  def security_mode_valid?
    MODES.include?(security_mode_id)
  end

  def security_mode_advanced?
    security_mode_id == ADVANCED
  end

  def security_mode_normal?
    security_mode_id == NORMAL
  end
end
