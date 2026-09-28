# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Principal effects (app realm).
class AppEnforcementPrincipalEffect < AppPrincipalRecord
  self.table_name = "app_enforcement_principal_effects"

  belongs_to :enforcement_case, class_name: "AppEnforcementCase", foreign_key: :app_enforcement_case_id,
                                inverse_of: :principal_effect

  validates :principal_public_id, presence: true
  validates :effective_at, presence: true
  # The columns are NOT NULL; a blank or unparseable flag is refused as invalid input instead of
  # reaching the database as a constraint violation.
  validates :access_blocking, :recovery_blocked, :reactivation_blocked, :withdrawal_purge_blocked,
            :principal_hard_delete_blocked, inclusion: { in: [true, false] }
  # D9: method_protection permits no Principal Effect at all.
  validate :kind_permits_principal_effect

  private

  def kind_permits_principal_effect
    return unless enforcement_case

    errors.add(
      :base,
      "method_protection Cases may not carry a Principal Effect",
    ) if enforcement_case.kind == "method_protection"
  end
end
