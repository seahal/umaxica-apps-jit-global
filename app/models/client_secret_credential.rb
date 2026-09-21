# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_secret_credentials
# Database name: app_principal
#
#  id                             :bigint           not null, primary key
#  consumed_at                    :datetime
#  delivery_method                :string
#  discard_at                   :datetime         default(Infinity), not null
#  failure_count                  :integer          default(0), not null
#  issued_at                      :datetime
#  issued_by_ref                  :string
#  issued_by_type                 :string
#  last_failed_at                 :datetime
#  last_used_at                   :datetime
#  locked_at                      :datetime
#  lookup_digest                  :string
#  max_failures                   :integer
#  max_uses                       :integer
#  name                           :string           default(""), not null
#  not_before_at                  :datetime
#  password_digest                :string           default(""), not null
#  purge_eligible_at                      :datetime         default(Infinity), not null
#  revoked_at                     :datetime
#  safe_prefix                    :string
#  scope                          :string
#  secret_kind                    :string
#  usage_policy                   :string
#  use_count                      :integer          default(0), not null
#  uses_remaining                 :integer          default(1), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  issued_by_id                   :bigint
#  public_id                      :string(21)       not null
#  user_id                        :bigint           not null
#  user_identity_secret_status_id :bigint           default(1), not null
#  user_secret_kind_id            :bigint           default(1), not null
#
# Indexes
#
#  idx_on_user_identity_secret_status_id_178d36c039        (user_identity_secret_status_id)
#  index_client_secret_credentials_on_lookup_digest        (lookup_digest)
#  index_client_secret_credentials_on_public_id            (public_id) UNIQUE
#  index_client_secret_credentials_on_user_id              (user_id)
#  index_client_secret_credentials_on_user_secret_kind_id  (user_secret_kind_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#  fk_rails_...  (user_identity_secret_status_id => client_secret_credential_statuses.id)
#  fk_rails_...  (user_secret_kind_id => client_secret_credential_kinds.id)
#

class ClientSecretCredential < AppPrincipalRecord
  include Retainable

  alias_attribute :user_secret_status_id, :user_identity_secret_status_id
  include ::PublicId
  include ::SecretCredential
  include ClientSecretCredentialKinds

  MAX_SECRETS_PER_USER = 20
  SIGN_IN_ALLOWED_STATUS_IDS = [ClientSecretCredentialStatus::ACTIVE].freeze
  SIGN_IN_ALLOWED_KIND_IDS = ClientSecretCredentialKind::ALLOWED_FOR_SECRET_SIGN_IN
  attr_accessor :raw_secret_credential

  attribute :user_identity_secret_status_id, default: ClientSecretCredentialStatus::ACTIVE
  attribute :user_secret_kind_id, default: ClientSecretCredentialKind::LOGIN

  belongs_to :user, class_name: "Client", inverse_of: :client_secret_credentials
  belongs_to :user_secret_credential_status, class_name: "ClientSecretCredentialStatus",
                                             inverse_of: :client_secret_credentials,
                                             foreign_key: :user_identity_secret_status_id
  belongs_to :user_secret_credential_kind, class_name: "ClientSecretCredentialKind",
                                           inverse_of: :client_secret_credentials,
                                           foreign_key: :user_secret_kind_id

  validates :name, length: { maximum: 255 }
  validates :password_digest, presence: true, length: { maximum: 255 }

  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :user,
                 association: :client_secret_credentials,
                 foreign_key: :user_id,
                 limit: :MAX_SECRETS_PER_USER,
                 record_name: "secret_credentials",
                 owner_name: "user"
  validates_with RecoveryIdentityRequiredValidator,
                 on: :create,
                 owner: :user,
                 message: Client::RECOVERY_IDENTITY_REQUIRED_MESSAGE

  scope :allowed_for_secret_credential_sign_in, lambda {
    where(
      user_identity_secret_status_id: SIGN_IN_ALLOWED_STATUS_IDS,
      user_secret_kind_id: SIGN_IN_ALLOWED_KIND_IDS,
    )
  }

  def self.identity_secret_credential_status_class
    ClientSecretCredentialStatus
  end

  def self.identity_secret_credential_status_id_column
    :user_identity_secret_status_id
  end

  def self.generate_raw_secret_credential(length: SECRET_PASSWORD_LENGTH)
    SecureRandom.base58(length)
  end

  # Alias for password to match controller params
  def value=(val)
    self.password = val
  end

  def value
    password
  end

  def enabled?
    active?
  end

  def usable_for_secret_credential_sign_in?(now: Time.current)
    return false unless sign_in_status_allowed?
    return false unless sign_in_kind_allowed?
    return false if expired_for_secret_credential_sign_in?(now)
    return true if permanent_secret_credential?

    Integer(uses_remaining.to_s, 10).positive?
  end

  def verify_for_secret_credential_sign_in!(raw_secret_credential, now: Time.current)
    with_lock do
      reload

      auth_result = authenticate(raw_secret_credential)
      return false unless sign_in_status_allowed?
      return false unless sign_in_kind_allowed?
      return false if expired_for_secret_credential_sign_in?(now)
      return false unless auth_result

      self.last_used_at = now
      if one_time_secret_credential?
        return false unless Integer(uses_remaining.to_s, 10).positive?

        self.uses_remaining -= 1
        self[self.class.identity_secret_credential_status_id_column] =
          self.class.status_id_for(:used) if uses_remaining.zero?
      end

      save!
    end

    true
  end

  def to_param
    public_id
  end

  private

  def sign_in_status_allowed?
    SIGN_IN_ALLOWED_STATUS_IDS.include?(user_secret_status_id)
  end

  def sign_in_kind_allowed?
    SIGN_IN_ALLOWED_KIND_IDS.include?(user_secret_kind_id)
  end

  # Secret sign-in keeps expiry inclusive: now <= expires_at is valid.
  def expired_for_secret_credential_sign_in?(now)
    return false if discard_at.nil?
    return false if discard_at.respond_to?(:infinite?) && discard_at.infinite?

    now > discard_at
  end
end
