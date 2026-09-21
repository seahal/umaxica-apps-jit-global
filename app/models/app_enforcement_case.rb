# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md: Enforcement Case for the app realm (Client).
class AppEnforcementCase < AppPrincipalRecord
  encrypts :reason_note

  include EnforcementCaseApplicable

  self.table_name = "app_enforcement_cases"

  has_one :principal_effect, class_name: "AppEnforcementPrincipalEffect", dependent: :destroy,
                             inverse_of: :enforcement_case
  has_many :authentication_method_effects, class_name: "AppEnforcementAuthenticationMethodEffect",
                                           dependent: :destroy,
                                           inverse_of: :enforcement_case
  has_many :identifier_effects, class_name: "AppEnforcementIdentifierEffect", dependent: :destroy,
                                inverse_of: :enforcement_case
  has_many :principal_links, class_name: "AppEnforcementPrincipalLink", dependent: :destroy,
                             inverse_of: :enforcement_case
  has_one :appeal, class_name: "AppEnforcementAppeal", dependent: :destroy, inverse_of: :enforcement_case

  def self.principal_class
    ::Client
  end

  def self.realm
    "app"
  end
end
