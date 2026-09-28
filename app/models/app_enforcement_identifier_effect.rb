# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Identifier effects (app realm). No FK to any
# principal (Purge protection) -- these rows must outlive the account they
# originated from. `display_value` is encrypted, distinct from the HMAC
# `lookup_digest` used for matching (D6, Encryption).
class AppEnforcementIdentifierEffect < AppPrincipalRecord
  self.table_name = "app_enforcement_identifier_effects"

  KINDS = %w(email telephone google_subject apple_subject identity_id).freeze

  encrypts :display_value

  belongs_to :enforcement_case, class_name: "AppEnforcementCase", foreign_key: :app_enforcement_case_id,
                                inverse_of: :identifier_effects

  scope :in_force, lambda {
    where(ended_at: nil)
      .where(app_enforcement_identifier_effects: { effective_at: ..Time.current })
      .where(
        "app_enforcement_identifier_effects.expires_at IS NULL OR " \
        "app_enforcement_identifier_effects.expires_at > ?", Time.current,
      )
  }

  class << self
    # adr/unified-enforcement.md, Identifier normalization / HMAC: capture
    # must happen before any anonymization step runs, since anonymization
    # nulls the credential digest the raw value can no longer be recovered
    # from (D6, ordering constraint).
    def build_for_email(value:, **attrs)
      digest = EnforcementIdentifierDigest.for_email(realm: "app", value: value)
      return nil unless digest

      new(**digest, **attrs)
    end

    def build_for_telephone(value:, **attrs)
      digest = EnforcementIdentifierDigest.for_telephone(realm: "app", value: value)
      return nil unless digest

      new(**digest, **attrs)
    end

    def build_for_google_subject(issuer:, subject:, **attrs)
      digest = EnforcementIdentifierDigest.for_google_subject(realm: "app", issuer: issuer, subject: subject)
      return nil unless digest

      new(**digest, **attrs)
    end

    def build_for_apple_subject(issuer:, subject:, **attrs)
      digest = EnforcementIdentifierDigest.for_apple_subject(realm: "app", issuer: issuer, subject: subject)
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
  # D9: Identifier Effect is only attachable to permanent_ban and cooldown Cases,
  # and is never auto-created by a method-only freeze.
  validate :kind_permits_identifier_effect

  private

  def kind_permits_identifier_effect
    return unless enforcement_case
    return if %w(permanent_ban cooldown).include?(enforcement_case.kind)

    errors.add(:base, "Identifier Effect is only legal on permanent_ban or cooldown Cases")
  end
end
