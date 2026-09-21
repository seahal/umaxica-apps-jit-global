# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md: Enforcement Case for the org realm (Operator).
class OrgEnforcementCase < OrgPrincipalRecord
  encrypts :reason_note

  include EnforcementCaseApplicable

  self.table_name = "org_enforcement_cases"

  has_one :principal_effect, class_name: "OrgEnforcementPrincipalEffect", dependent: :destroy,
                             inverse_of: :enforcement_case
  has_many :authentication_method_effects, class_name: "OrgEnforcementAuthenticationMethodEffect",
                                           dependent: :destroy, inverse_of: :enforcement_case
  has_many :identifier_effects, class_name: "OrgEnforcementIdentifierEffect", dependent: :destroy,
                                inverse_of: :enforcement_case
  has_many :principal_links, class_name: "OrgEnforcementPrincipalLink", dependent: :destroy,
                             inverse_of: :enforcement_case
  has_one :appeal, class_name: "OrgEnforcementAppeal", dependent: :destroy, inverse_of: :enforcement_case

  def self.principal_class
    ::Operator
  end

  def self.realm
    "org"
  end
end
