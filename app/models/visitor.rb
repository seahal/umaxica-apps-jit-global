# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitors
# Database name: com_zenith
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
#  public_id                   :string           default(""), not null
#  status_id                   :bigint           default(2), not null
#  visibility_id               :bigint           default(1), not null
#
# Indexes
#
#  index_visitors_on_access_state           (access_state)
#  index_visitors_on_admin_locked_at        (admin_locked_at) WHERE (admin_locked_at IS NOT NULL)
#  index_visitors_on_deactivated_at         (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_visitors_on_discarded_at           (discarded_at)
#  index_visitors_on_mfa_level_id           (mfa_level_id)
#  index_visitors_on_mfa_status_id          (mfa_status_id)
#  index_visitors_on_public_id              (public_id) UNIQUE
#  index_visitors_on_purged_at              (purged_at)
#  index_visitors_on_status_id              (status_id)
#  index_visitors_on_terminated_at          (terminated_at) WHERE (terminated_at IS NOT NULL)
#  index_visitors_on_token_valid_after_at   (token_valid_after_at) WHERE (token_valid_after_at IS NOT NULL)
#  index_visitors_on_visibility_id          (visibility_id)
#  index_visitors_on_webauthn_user_handle   (webauthn_user_handle) UNIQUE
#  index_visitors_on_withdrawal_started_at  (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_visitors_on_withdrawn_at           (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (mfa_level_id => visitor_mfa_levels.id)
#  fk_rails_...  (mfa_status_id => visitor_mfa_statuses.id)
#  fk_rails_...  (status_id => visitor_statuses.id)
#  fk_rails_...  (visibility_id => visitor_visibilities.id)
#

class Visitor < ComPrincipalRecord
  # rubocop:disable Rails/HasManyOrHasOneDependent
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

  LOGIN_BLOCKED_STATUS_IDS = [VisitorStatus::RESERVED].freeze
  VERIFIED_RECOVERY_EMAIL_STATUS_IDS = [
    VisitorEmailStatus::VERIFIED,
    VisitorEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS = [
    VisitorTelephoneStatus::VERIFIED,
    VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  RECOVERY_IDENTITY_REQUIRED_MESSAGE = I18n.t("models.visitor.recovery_identity_required")

  attribute :status_id, default: VisitorStatus::NOTHING
  validates :status_id, numericality: { only_integer: true }
  mfa_level_reference VisitorMfaLevel
  mfa_status_reference VisitorMfaStatus

  belongs_to :visitor_status,
             class_name: "VisitorStatus",
             foreign_key: :status_id,
             inverse_of: :visitors
  belongs_to :mfa_level,
             class_name: "VisitorMfaLevel",
             inverse_of: :visitors
  belongs_to :mfa_status,
             class_name: "VisitorMfaStatus",
             inverse_of: :visitors
  belongs_to :visibility,
             class_name: "VisitorVisibility",
             inverse_of: :visitors
  has_one :visitor_preference,
          dependent: :destroy,
          inverse_of: :visitor
  has_many :visitor_emails,
           dependent: :destroy,
           inverse_of: :visitor
  has_many :visitor_withdrawal_flows,
           dependent: :restrict_with_error,
           inverse_of: :visitor
  has_many :visitor_withdrawal_ceremonies,
           dependent: :delete_all,
           inverse_of: :visitor
  has_many :visitor_privacy_requests,
           dependent: :restrict_with_error,
           inverse_of: :visitor
  has_many :visitor_retention_holds,
           dependent: :restrict_with_error,
           inverse_of: :visitor
  has_many :visitor_telephones,
           dependent: :destroy,
           inverse_of: :visitor
  has_many :visitor_secret_credentials,
           dependent: :destroy,
           inverse_of: :visitor
  has_many :visitor_passkeys,
           dependent: :destroy,
           inverse_of: :visitor
  has_many :visitor_tokens,
           dependent: :delete_all,
           inverse_of: :visitor
  has_many :visitor_device_sessions,
           dependent: :destroy,
           inverse_of: :visitor
  has_many :visitor_banners,
           dependent: :destroy,
           inverse_of: :visitor
  has_many :oidc_connections,
           class_name: "VisitorOidcConnection",
           dependent: :destroy,
           inverse_of: :visitor
  # Cross-database (com_signal DB). Purged explicitly via
  # RetentionCrossDatabaseChildPurge from the account purge path, not by an
  # implicit cross-DB AR cascade.
  has_many :notification_records,
           class_name: "VisitorNotificationRecord",
           inverse_of: :visitor
  # Cross-database (com_zenith DB). Purged explicitly via
  # RetentionCrossDatabaseChildPurge, not by an implicit cross-DB cascade.
  has_one :rp_account,
          class_name: "VisitorAccount",
          inverse_of: :visitor,
          dependent: :destroy
  has_one :core_com_visitor_bridge,
          dependent: :destroy,
          inverse_of: :visitor

  def staff?
    false
  end

  def user?
    false
  end

  def visitor?
    true
  end

  def has_verified_recovery_identity?
    has_verified_pii?
  end

  def has_verified_pii?
    verified_email? || verified_telephone?
  end

  def verified_email?
    if visitor_emails.loaded?
      visitor_emails.any? { |e| VERIFIED_RECOVERY_EMAIL_STATUS_IDS.include?(e.visitor_email_status_id) }
    else
      visitor_emails.exists?(visitor_email_status_id: VERIFIED_RECOVERY_EMAIL_STATUS_IDS)
    end
  end

  def verified_telephone?
    if visitor_telephones.loaded?
      visitor_telephones.any? { |t| VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS.include?(t.visitor_telephone_status_id) }
    else
      visitor_telephones.exists?(visitor_telephone_status_id: VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS)
    end
  end

  def passkey_login_available?
    has_active_passkey =
      if visitor_passkeys.loaded?
        visitor_passkeys.any? { |passkey| passkey.status_id == VisitorPasskeyStatus::ACTIVE }
      else
        visitor_passkeys.active.exists?
      end
    return false unless has_active_passkey

    verified_telephone?
  end

  private

  def configured_mfa_level_methods
    step_up_methods
  end
end
