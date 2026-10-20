# typed: false
# frozen_string_literal: true

class AppEnforcementAppeal < AppPrincipalRecord
  validates :app_enforcement_case_id, uniqueness: true

  include EnforcementAppeal

  belongs_to :enforcement_case, class_name: "AppEnforcementCase", foreign_key: :app_enforcement_case_id,
                                inverse_of: :appeal
end
