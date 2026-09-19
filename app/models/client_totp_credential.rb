# typed: false
# frozen_string_literal: true

# frozen_string_literal: true

# == Schema Information
#
# Table name: client_totp_credentials
# Database name: app_principal
#
#  id                                      :bigint           not null, primary key
#  last_otp_at                             :datetime         default(-Infinity), not null
#  locked_at                               :datetime         default(-Infinity), not null
#  otp_attempt_window_started_at           :datetime         default(-Infinity), not null
#  otp_attempts_count                      :integer          default(0), not null
#  private_key                             :string(1024)     default(""), not null
#  title                                   :string(32)
#  created_at                              :datetime         not null
#  updated_at                              :datetime         not null
#  public_id                               :string(21)       not null
#  user_id                                 :bigint           not null
#  user_identity_totp_credential_status_id :bigint           default(5), not null
#
# Indexes
#
#  idx_on_user_identity_totp_credential_status_id_47a8d28ad3  (user_identity_totp_credential_status_id)
#  index_client_totp_credentials_on_public_id                 (public_id) UNIQUE
#  index_client_totp_credentials_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#  fk_rails_...  (user_identity_totp_credential_status_id => client_totp_credential_statuses.id)
#

class ClientTotpCredential < AppPrincipalRecord
  include ::PublicId
  include MfaStatusCredential

  encrypts :private_key

  alias_attribute :user_totp_credential_status_id, :user_identity_totp_credential_status_id
  MAX_TOTPS_PER_USER = 2

  # Retry protection for TOTP verification. PostgreSQL is the source of truth so that a
  # rate-limit store outage or flush cannot reset it. The values are the per-account limit the
  # sign-in challenge already enforced through `rate_limit` (10 per 15 minutes, retry after 900
  # seconds); that rule remains as an auxiliary throttle. Column semantics follow OtpLockable:
  # `locked_at` is the instant the lockout ends, and the "-infinity" sentinel means not locked.
  MAX_TOTP_ATTEMPTS = 10
  TOTP_ATTEMPT_WINDOW = 15.minutes
  TOTP_LOCKOUT_DURATION = 15.minutes
  TOTP_UNLOCKED_SENTINEL = -Float::INFINITY

  attr_accessor :first_token

  belongs_to :user, class_name: "Client", inverse_of: :client_totp_credentials
  mfa_status_owner :user
  belongs_to :user_totp_credential_status,
             class_name: "ClientTotpCredentialStatus",
             inverse_of: :client_totp_credentials,
             foreign_key: :user_identity_totp_credential_status_id
  attribute :user_identity_totp_credential_status_id, default: ClientTotpCredentialStatus::NOTHING

  validates :private_key, presence: true, length: { maximum: 1024 }
  validates :last_otp_at, presence: true
  validates :title, length: { maximum: 32 }, allow_blank: true
  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :user,
                 association: :client_totp_credentials,
                 foreign_key: :user_id,
                 limit: :MAX_TOTPS_PER_USER,
                 record_name: "totps",
                 owner_name: "user"

  after_initialize :generate_private_key_if_blank
  after_initialize :generate_public_id_if_blank

  public

  # The instant the lockout ends, or nil when the credential is not locked at `now`.
  def totp_locked_until(now)
    value = locked_at
    return nil if value.blank? || (value.respond_to?(:infinite?) && value.infinite?)

    (value > now) ? value : nil
  end

  # Records one failed verification. The caller must hold this row's lock (see
  # TotpWindowConsumer), so the read-modify-write below cannot lose a concurrent update. Uses
  # save!(validate: false) for the same reason as OtpLockable#increment_attempts!: an internal
  # counter bump must not be blocked by unrelated validations.
  def record_totp_failure!(now)
    return if totp_locked_until(now)

    unless totp_attempt_window_active?(now)
      self.otp_attempts_count = 0
      self.otp_attempt_window_started_at = now
    end

    self.otp_attempts_count = otp_attempts_count.to_i + 1
    self.locked_at = now + TOTP_LOCKOUT_DURATION if otp_attempts_count >= MAX_TOTP_ATTEMPTS
    save!(validate: false)
  end

  # Clears the failure state after a successful verification. The caller holds the row lock.
  def reset_totp_attempts!
    self.otp_attempts_count = 0
    self.otp_attempt_window_started_at = TOTP_UNLOCKED_SENTINEL
    self.locked_at = TOTP_UNLOCKED_SENTINEL
    save!(validate: false)
  end

  private

  def totp_attempt_window_active?(now)
    started = otp_attempt_window_started_at
    return false if started.blank? || (started.respond_to?(:infinite?) && started.infinite?)

    started > now - TOTP_ATTEMPT_WINDOW
  end

  def generate_public_id_if_blank
    return unless has_attribute?(:public_id)

    self.public_id = Nanoid.generate(size: 21) if self[:public_id].blank?
  end

  def generate_private_key_if_blank
    self.private_key = ROTP::Base32.random_base32 if read_attribute_before_type_cast("private_key").blank?
  end
end
