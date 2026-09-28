# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Identifier effects (com realm -- no social login).
class ComEnforcementIdentifierEffect < ComPrincipalRecord
  self.table_name = "com_enforcement_identifier_effects"

  KINDS = %w(email telephone identity_id).freeze

  encrypts :display_value

  belongs_to :enforcement_case, class_name: "ComEnforcementCase", foreign_key: :com_enforcement_case_id,
                                inverse_of: :identifier_effects

  scope :in_force, lambda {
    where(ended_at: nil)
      .where(com_enforcement_identifier_effects: { effective_at: ..Time.current })
      .where(
        "com_enforcement_identifier_effects.expires_at IS NULL OR " \
        "com_enforcement_identifier_effects.expires_at > ?", Time.current,
      )
  }

  class << self
    def build_for_email(value:, **attrs)
      digest = EnforcementIdentifierDigest.for_email(realm: "com", value: value)
      return nil unless digest

      new(**digest, **attrs)
    end

    def build_for_telephone(value:, **attrs)
      digest = EnforcementIdentifierDigest.for_telephone(realm: "com", value: value)
      return nil unless digest

      new(**digest, **attrs)
    end
  end

  validates :identifier_kind, presence: true, inclusion: { in: KINDS }
  validates :lookup_digest, presence: true
  validates :key_version, :digest_version, :normalization_version, presence: true
  validates :effective_at, presence: true
  # The columns are NOT NULL; a blank or unparseable flag is refused as invalid input instead of
  # reaching the database as a constraint violation.
  validates :registration_blocked, :attachment_blocked, :recovery_blocked, inclusion: { in: [true, false] }
  validate :kind_permits_identifier_effect

  private

  def kind_permits_identifier_effect
    return unless enforcement_case
    return if %w(permanent_ban cooldown).include?(enforcement_case.kind)

    errors.add(:base, "Identifier Effect is only legal on permanent_ban or cooldown Cases")
  end
end
