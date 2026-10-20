# typed: false
# frozen_string_literal: true

class ComEnforcementAppeal < ComPrincipalRecord
  validates :com_enforcement_case_id, uniqueness: true

  include EnforcementAppeal

  belongs_to :enforcement_case, class_name: "ComEnforcementCase", foreign_key: :com_enforcement_case_id,
                                inverse_of: :appeal
end
