# frozen_string_literal: true
# typed: false

class ClientPreferenceStatus < AppPrincipalRecord
  include ReferenceRecord

  ACTIVE = 0
  RETIRED = 1
  DEFAULTS = [ACTIVE, RETIRED].freeze

  has_many :client_preferences, foreign_key: :status_id,
                                inverse_of: :client_preference_status,
                                dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  public_class_method :ensure_defaults!
end
