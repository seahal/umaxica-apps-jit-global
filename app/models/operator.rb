# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operators
# Database name: org_zenith
#
#  id                          :bigint           not null, primary key
#  access_state                :string           default("enabled"), not null
#  admin_locked_at             :datetime
#  admin_locked_reason_code    :string
#  admin_locked_reason_note    :text
#  birthdate                   :text
#  deactivated_at              :datetime
#  discarded_at                :datetime         default(Infinity), not null
#  lock_version                :integer          default(0), not null
#  mfa_level_enabled           :boolean          default(FALSE), not null
#  purged_at                   :datetime         default(Infinity), not null
#  reactivated_at              :datetime
#  token_valid_after_at        :datetime
#  webauthn_user_handle        :string           not null
#  withdrawal_started_at       :datetime
#  withdrawn_at                :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  admin_locked_by_operator_id :bigint
#  mfa_level_id                :bigint           default(0), not null
#  mfa_status_id               :bigint           default(5), not null
#  public_id                   :string(16)       not null
#  status_id                   :bigint           default(2), not null
#  visibility_id               :bigint           default(2), not null
#
# Indexes
#
#  index_operators_on_access_state           (access_state)
#  index_operators_on_admin_locked_at        (admin_locked_at) WHERE (admin_locked_at IS NOT NULL)
#  index_operators_on_deactivated_at         (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_operators_on_discarded_at           (discarded_at)
#  index_operators_on_mfa_level_id           (mfa_level_id)
#  index_operators_on_mfa_status_id          (mfa_status_id)
#  index_operators_on_public_id              (public_id) UNIQUE
#  index_operators_on_purged_at              (purged_at)
#  index_operators_on_status_id              (status_id)
#  index_operators_on_token_valid_after_at   (token_valid_after_at) WHERE (token_valid_after_at IS NOT NULL)
#  index_operators_on_visibility_id          (visibility_id)
#  index_operators_on_webauthn_user_handle   (webauthn_user_handle) UNIQUE
#  index_operators_on_withdrawal_started_at  (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_operators_on_withdrawn_at           (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (mfa_level_id => operator_mfa_levels.id)
#  fk_rails_...  (mfa_status_id => operator_mfa_statuses.id)
#  fk_rails_...  (status_id => operator_statuses.id)
#  fk_rails_...  (visibility_id => operator_visibilities.id)
#

class Operator < OrgPrincipalRecord
  # rubocop:disable Rails/HasManyOrHasOneDependent
  include Retainable
  include HasBirthdate

  # Operator represents an authenticated actor for the org console.
  # It mirrors `User` for identity concerns but is used for org-scoped access.
  self.ignored_columns += ["operator_id", "webauthn_id"]

  include ::Identity
  include AuthenticationCredentialInventoryOwner
  include WebauthnUserHandleOwner
  include MfaLevelConfigurable
  include MfaStatusTrackable
  include ActorLifecycleConsistency
  include AdministrativeAccessLockable

  LOGIN_BLOCKED_STATUS_IDS = [OperatorStatus::RESERVED].freeze
  PUBLIC_ID_LENGTH = 16
  PUBLIC_ID_ALPHABET = SecureRandom::BASE32_ALPHABET.join.freeze
  PUBLIC_ID_FORMAT = /\A[0-9A-FGHJKMNPQRSTVWXYZ]{16}\z/
  MAX_PUBLIC_ID_RETRIES = 5

  attribute :status_id, default: OperatorStatus::NOTHING
  validates :status_id, numericality: { only_integer: true }
  mfa_level_reference OperatorMfaLevel
  mfa_status_reference OperatorMfaStatus

  belongs_to :staff_status, class_name: "OperatorStatus", foreign_key: :status_id,
                            inverse_of: :staffs
  belongs_to :mfa_level,
             class_name: "OperatorMfaLevel",
             inverse_of: :staffs
  belongs_to :mfa_status,
             class_name: "OperatorMfaStatus",
             inverse_of: :staffs
  belongs_to :visibility,
             class_name: "OperatorVisibility",
             inverse_of: :staffs
  has_many :staff_emails, class_name: "OperatorEmail", dependent: :restrict_with_error,
                          inverse_of: :staff
  has_many :operator_emails, class_name: "OperatorEmail", foreign_key: :staff_id,
                             inverse_of: :staff
  has_many :staff_telephones, class_name: "OperatorTelephone", dependent: :restrict_with_error,
                              inverse_of: :staff
  has_many :operator_telephones, class_name: "OperatorTelephone", foreign_key: :staff_id,
                                 inverse_of: :staff
  has_many :staff_passkeys, class_name: "OperatorPasskey", dependent: :destroy,
                            inverse_of: :staff
  has_many :operator_passkeys, class_name: "OperatorPasskey", foreign_key: :staff_id,
                               inverse_of: :staff
  # Cross-database (chronicle DB): append-only audit history. No dependent:
  # cascade -- audit records intentionally outlive actor purge and are not
  # mutated/deleted across the DB boundary. See
  # adr/chronicle-audit-db-consolidation.md.
  has_many :staff_chronicles,
           -> { where(subject_type: "Operator") },
           class_name: "OperatorChronicle",
           foreign_key: :subject_id,
           inverse_of: false
  # Cross-database (chronicle DB), polymorphic audit history. See above.
  has_many :client_chronicles,
           as: :actor
  has_many :staff_secret_credentials, class_name: "OperatorSecretCredential", dependent: :destroy,
                                      inverse_of: :staff
  has_many :operator_secret_credentials, class_name: "OperatorSecretCredential", foreign_key: :staff_id,
                                         inverse_of: :staff
  has_many :staff_tokens, class_name: "OperatorToken", dependent: :destroy,
                          inverse_of: :staff
  has_many :operator_device_sessions,
           class_name: "OperatorDeviceSession",
           foreign_key: :staff_id,
           dependent: :destroy,
           inverse_of: :staff
  has_many :operator_tokens, class_name: "OperatorToken", foreign_key: :staff_id,
                             inverse_of: :staff
  has_many :oidc_connections,
           class_name: "OperatorOidcConnection",
           foreign_key: :staff_id,
           dependent: :destroy,
           inverse_of: :staff
  # Cross-database (org_signal DB). Purged explicitly via
  # RetentionCrossDatabaseChildPurge from the operator purge path, not by an
  # implicit cross-DB AR cascade.
  has_many :notification_records,
           class_name: "OperatorNotificationRecord",
           foreign_key: :staff_id,
           inverse_of: :operator
  has_many :staff_operators, class_name: "OperatorWorkspaceAccountMembership",
                             foreign_key: :staff_id,
                             dependent: :destroy,
                             inverse_of: false
  has_many :operator_workspace_accounts,
           class_name: "OperatorWorkspaceAccount",
           foreign_key: :staff_id,
           inverse_of: false,
           dependent: :destroy
  has_many :staff_bulletins, class_name: "OperatorBulletin", dependent: :destroy, inverse_of: :staff
  has_many :staff_banners, class_name: "OperatorBanner", dependent: :destroy, inverse_of: :staff
  has_one :rp_account, class_name: "OperatorAccount", dependent: :destroy, inverse_of: :staff
  has_one :core_org_operator_bridge,
          dependent: :destroy,
          inverse_of: :operator
  has_one :staff_preference, class_name: "OperatorPreference", dependent: :destroy, inverse_of: :staff

  validates :public_id,
            presence: true,
            uniqueness: true,
            length: { is: PUBLIC_ID_LENGTH },
            format: {
              with: PUBLIC_ID_FORMAT,
              message: :invalid_format,
            }
  before_validation :normalize_public_id
  before_validation :assign_public_id!, on: :create
  before_save :normalize_public_id
  around_create :retry_on_public_id_collision

  def operator?
    true
  end

  def user?
    false
  end

  def self.generate_public_id
    Array.new(PUBLIC_ID_LENGTH) { PUBLIC_ID_ALPHABET[SecureRandom.random_number(PUBLIC_ID_ALPHABET.length)] }.join
  end

  delegate :generate_public_id, to: :class

  def public_id=(value)
    @public_id_supplied = true unless @_assigning_public_id_internally
    super
  end

  def self.normalize_public_id(value)
    return value if value.nil?

    value.strip.gsub(/[-_]/, "").upcase
  end

  private

  def configured_mfa_level_methods
    step_up_methods
  end

  def normalize_public_id
    return if public_id.nil?

    assign_public_id_value(self.class.normalize_public_id(public_id))
  end

  def assign_public_id!
    return if public_id.present? || explicit_blank_public_id_input?

    loop do
      assign_public_id_value(generate_public_id)
      break unless self.class.exists?(public_id: public_id)
    end
  end

  def retry_on_public_id_collision
    attempts = 0

    begin
      yield
    rescue ActiveRecord::RecordNotUnique => e
      attempts += 1

      if attempts <= MAX_PUBLIC_ID_RETRIES
        assign_public_id_value(nil)
        assign_public_id!
        retry
      end

      Rails.logger.error(
        "[Operator] Failed to generate unique public_id after #{MAX_PUBLIC_ID_RETRIES} retries: " \
        "#{e.class}: #{e.message} (last public_id=#{public_id.inspect})",
      )
      Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
      raise
    end
  end

  def explicit_blank_public_id_input?
    @public_id_supplied && self.class.normalize_public_id(public_id).blank?
  end

  def assign_public_id_value(value)
    @_assigning_public_id_internally = true
    self.public_id = value
  ensure
    @_assigning_public_id_internally = false
  end
end
