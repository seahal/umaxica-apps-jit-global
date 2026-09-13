# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: clients
# Database name: app_zenith
#
#  id                          :bigint           not null, primary key
#  access_state                :string           default("enabled"), not null
#  admin_locked_at             :datetime
#  admin_locked_reason_code    :string
#  admin_locked_reason_note    :text
#  birthdate                   :text
#  deactivated_at              :datetime
#  discarded_at                :datetime         default(Infinity), not null
#  last_step_up_at             :datetime
#  lock_version                :integer          default(0), not null
#  mfa_level_enabled           :boolean          default(FALSE), not null
#  purged_at                   :datetime         default(Infinity), not null
#  reactivated_at              :datetime
#  terminated_at               :datetime
#  token_valid_after_at        :datetime
#  webauthn_user_handle        :string           not null
#  withdrawal_started_at       :datetime
#  withdrawn_at                :datetime         default(Infinity)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  admin_locked_by_operator_id :bigint
#  mfa_level_id                :bigint           default(0), not null
#  mfa_status_id               :bigint           default(5), not null
#  public_id                   :string(255)      default(""), not null
#  status_id                   :bigint           default(11), not null
#  visibility_id               :bigint           default(2), not null
#
# Indexes
#
#  index_clients_on_access_state           (access_state)
#  index_clients_on_admin_locked_at        (admin_locked_at) WHERE (admin_locked_at IS NOT NULL)
#  index_clients_on_deactivated_at         (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_clients_on_discarded_at           (discarded_at)
#  index_clients_on_mfa_level_id           (mfa_level_id)
#  index_clients_on_mfa_status_id          (mfa_status_id)
#  index_clients_on_public_id              (public_id) UNIQUE
#  index_clients_on_purged_at              (purged_at) WHERE (purged_at IS NOT NULL)
#  index_clients_on_status_id              (status_id)
#  index_clients_on_terminated_at          (terminated_at) WHERE (terminated_at IS NOT NULL)
#  index_clients_on_token_valid_after_at   (token_valid_after_at) WHERE (token_valid_after_at IS NOT NULL)
#  index_clients_on_visibility_id          (visibility_id)
#  index_clients_on_webauthn_user_handle   (webauthn_user_handle) UNIQUE
#  index_clients_on_withdrawal_started_at  (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_clients_on_withdrawn_at           (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (mfa_level_id => client_mfa_levels.id)
#  fk_rails_...  (mfa_status_id => client_mfa_statuses.id)
#  fk_rails_...  (status_id => client_statuses.id)
#  fk_rails_...  (visibility_id => client_visibilities.id)
#

# Lifecycle column reference (see adr/retention-lifecycle-column-boundary.md):
#
# * `discarded_at` / `purged_at` -- Retainable retention contract. The only
#   columns the `RetentionPurgeJob` consults for delete eligibility.
# * `withdrawal_started_at` -- Sign-out / withdrawal flow started.
# * `withdrawn_at` -- Withdrawal flow finalized. Retention is independent.
# * `deactivated_at` -- Withdrawal/suspension lifecycle marker. Reversible. Not a
#   deletion signal. Forced administrative access removal is represented by
#   `access_state: "admin_locked"` plus the `admin_locked_*` metadata columns.
# * `terminated_at` -- Set by `RetentionPurgeJob#anonymize_accounts` AFTER
#   `WithdrawalPersonalDataAnonymizer` finishes. Marks "PII has been scrubbed
#   on this row"; distinct from `discarded_at` (logical hide) and `purged_at`
#   (physical delete). Anonymized rows are retained for audit linkage with
#   anonymous PII placeholders.
class Client < AppPrincipalRecord
  include Retainable
  include Withdrawable
  include HasBirthdate
  include ::PublicId
  include ::Identity
  include AuthenticationCredentialInventoryOwner
  include WebauthnUserHandleOwner
  include MfaLevelConfigurable
  include MfaStatusTrackable
  include ActorLifecycleConsistency
  include AdministrativeAccessLockable

  LOGIN_BLOCKED_STATUS_IDS = [ClientStatus::RESERVED].freeze
  # what is this?
  VERIFIED_RECOVERY_EMAIL_STATUS_IDS = [
    ClientEmailStatus::VERIFIED,
    ClientEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS = [
    ClientTelephoneStatus::VERIFIED,
    ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  RECOVERY_IDENTITY_REQUIRED_MESSAGE = I18n.t("models.user.recovery_identity_required")

  attribute :status_id, default: ClientStatus::NOTHING
  validates :status_id, numericality: { only_integer: true }
  mfa_level_reference ClientMfaLevel
  mfa_status_reference ClientMfaStatus

  belongs_to :user_status, class_name: "ClientStatus",
                           foreign_key: :status_id,
                           inverse_of: :users
  belongs_to :mfa_level,
             class_name: "ClientMfaLevel",
             inverse_of: :users
  belongs_to :mfa_status,
             class_name: "ClientMfaStatus",
             inverse_of: :users
  belongs_to :visibility,
             class_name: "ClientVisibility",
             inverse_of: :users
  has_many :client_external_identities,
           dependent: :destroy,
           inverse_of: :client
  has_many :client_apple_notification_events,
           dependent: :nullify,
           inverse_of: :client
  has_many :client_emails,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_telephones,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_secret_credentials,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_totp_credentials,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_passkeys,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_withdrawal_flows,
           dependent: :restrict_with_error,
           inverse_of: :client
  has_many :client_withdrawal_ceremonies,
           dependent: :delete_all,
           inverse_of: :client
  has_many :client_privacy_requests,
           dependent: :restrict_with_error,
           inverse_of: :client
  has_many :client_retention_holds,
           dependent: :restrict_with_error,
           inverse_of: :client
  has_many :active_totps,
           -> { where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE) },
           class_name: "ClientTotpCredential",
           dependent: :restrict_with_exception,
           inverse_of: :user

  # Cross-database (chronicle DB): append-only audit history. No dependent:
  # cascade -- audit records intentionally outlive actor purge and are not
  # deleted across the DB boundary. See adr/chronicle-audit-db-consolidation.md.
  has_many :client_chronicles, # rubocop:disable Rails/HasManyOrHasOneDependent
           foreign_key: :subject_id,
           inverse_of: false
  has_many :client_tokens,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_device_sessions,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :oidc_connections,
           class_name: "ClientOidcConnection",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_memberships,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  # Cross-database (chronicle DB), polymorphic audit history. No dependent:
  # cascade -- see client_chronicles above.
  has_many :staff_chronicles, class_name: "OperatorChronicle", as: :actor # rubocop:disable Rails/HasManyOrHasOneDependent
  # Cross-database (app_signal DB). Lifecycle is NOT an implicit AR cascade
  # across the DB boundary; purged explicitly via
  # RetentionCrossDatabaseChildPurge from the account purge path.
  has_many :notification_records, # rubocop:disable Rails/HasManyOrHasOneDependent
           class_name: "ClientNotificationRecord",
           foreign_key: :user_id,
           inverse_of: :client
  has_many :clients,
           class_name: "ClientProfile",
           foreign_key: :user_id,
           dependent: :nullify,
           inverse_of: false
  has_many :client_banners,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_members,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_discoveries,
           class_name: "ClientMemberDiscovery",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_observations,
           class_name: "ClientMemberObservation",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_revocations,
           class_name: "ClientMemberRevocation",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_impersonations,
           class_name: "ClientMemberImpersonation",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_suspensions,
           class_name: "ClientMemberSuspension",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_deletions,
           class_name: "ClientMemberDeletion",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :members,
           through: :client_members
  has_many :owned_members,
           class_name: "Member",
           foreign_key: :user_id,
           dependent: :nullify,
           inverse_of: :user
  has_many :client_bulletins, foreign_key: :user_id, dependent: :destroy, inverse_of: :user
  has_one :rp_account, class_name: "ClientAccount", foreign_key: :user_id, dependent: :destroy, inverse_of: :user
  has_one :core_app_client_bridge,
          dependent: :destroy,
          inverse_of: :client
  has_one :user_preference, class_name: "ClientPreference", foreign_key: :user_id, dependent: :destroy,
                            inverse_of: :user
  # Cross-database (avatar DB). Join rows are purged explicitly via
  # RetentionCrossDatabaseChildPurge, not by an implicit cross-DB cascade.
  has_many :avatar_assignments, foreign_key: :user_id, inverse_of: :user # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :assigned_avatars, through: :avatar_assignments, source: :avatar
  has_many :owned_avatars,
           -> { joins(:avatar_assignments).where(avatar_assignments: { role: "owner" }) },
           through: :avatar_assignments,
           source: :avatar
  validates :public_id, uniqueness: true, length: { maximum: 21 }
  include Retainable

  def totp_enabled?
    if client_totp_credentials.loaded?
      client_totp_credentials.any? { |otp| otp.user_totp_credential_status_id == ClientTotpCredentialStatus::ACTIVE }
    else
      client_totp_credentials.exists?(user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
    end
  end

  def staff?
    false
  end

  def user?
    true
  end

  def client?
    true
  end

  def client_google_identities
    identity = client_external_identities.find_by(provider: "google")
    identity ? [identity] : []
  end

  # what is this?
  def has_verified_recovery_identity?
    has_verified_pii?
  end

  def has_verified_pii?
    verified_email? || verified_telephone?
  end

  def login_methods_remaining?(excluding_provider: nil)
    remaining_login_methods(excluding_provider: excluding_provider).any?
  end

  def social_unlink_methods_remaining?(excluding_provider:)
    remaining_social_unlink_methods(excluding_provider: excluding_provider).any?
  end

  def remaining_social_unlink_methods(excluding_provider:)
    excluded = SocialIdentifiable.normalize_provider(excluding_provider)
    methods = []
    methods << :email if client_emails.exists?(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
    methods << :passkey if client_passkeys.exists?(status_id: ClientPasskeyStatus::ACTIVE)
    methods << :google if excluded != "google" && active_google_identity_exists?
    methods << :apple if excluded != "apple" && active_apple_identity_exists?
    methods
  end

  def remaining_login_methods(excluding_provider: nil)
    excluded = excluding_provider.present? ? SocialIdentifiable.normalize_provider(excluding_provider) : nil
    methods = authentication_credential_inventory.aal1_methods.map { |method| (method == :email_otp) ? :email : method }
    return methods unless excluded

    methods - [excluded.to_sym]
  end

  def active_social_provider?(provider)
    normalized = SocialIdentifiable.normalize_provider(provider)
    client_external_identities.exists?(provider: normalized, state: "active")
  end

  def active_google_identity_exists?
    client_external_identities.exists?(provider: "google", state: "active")
  end

  def active_apple_identity_exists?
    client_external_identities.exists?(provider: "apple", state: "active")
  end

  def verified_email?
    return client_emails.any? { |e|
      VERIFIED_RECOVERY_EMAIL_STATUS_IDS.include?(e.user_email_status_id)
    } if client_emails.loaded?

    client_emails.exists?(user_email_status_id: VERIFIED_RECOVERY_EMAIL_STATUS_IDS)
  end

  def verified_telephone?
    return client_telephones.any? { |t|
      VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS.include?(t.user_identity_telephone_status_id)
    } if client_telephones.loaded?

    client_telephones.exists?(user_identity_telephone_status_id: VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS)
  end

  def passkey_login_available?
    has_active_passkey =
      if client_passkeys.loaded?
        client_passkeys.any? { |passkey| passkey.status_id == ClientPasskeyStatus::ACTIVE }
      else
        client_passkeys.active.exists?
      end
    return false unless has_active_passkey

    verified_telephone?
  end

  private

  def configured_mfa_level_methods
    step_up_methods
  end
end
