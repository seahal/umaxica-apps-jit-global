# typed: false
# frozen_string_literal: true

class OrgEnforcementAppeal < OrgPrincipalRecord
  validates :org_enforcement_case_id, uniqueness: true

  include EnforcementAppeal

  belongs_to :enforcement_case, class_name: "OrgEnforcementCase", foreign_key: :org_enforcement_case_id,
                                inverse_of: :appeal
end
