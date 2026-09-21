# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_secret_credentials
# Database name: org_principal
#
#  id                              :bigint           not null, primary key
#  consumed_at                     :datetime
#  delivery_method                 :string
#  discard_at                    :datetime         default(Infinity), not null
#  failure_count                   :integer          default(0), not null
#  issued_at                       :datetime
#  issued_by_ref                   :string
#  issued_by_type                  :string
#  last_failed_at                  :datetime
#  last_used_at                    :datetime
#  locked_at                       :datetime
#  lookup_digest                   :string
#  max_failures                    :integer
#  max_uses                        :integer
#  name                            :string           not null
#  not_before_at                   :datetime
#  password_digest                 :string
#  purge_eligible_at                       :datetime         default(Infinity), not null
#  revoked_at                      :datetime
#  safe_prefix                     :string
#  scope                           :string
#  secret_kind                     :string
#  usage_policy                    :string
#  use_count                       :integer          default(0), not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  issued_by_id                    :bigint
#  public_id                       :string(21)       not null
#  staff_id                        :bigint           not null
#  staff_identity_secret_status_id :bigint           default(1), not null
#  staff_secret_kind_id            :bigint           default(2), not null
#
# Indexes
#
#  idx_on_staff_identity_secret_status_id_1e2bab9ca1          (staff_identity_secret_status_id)
#  index_operator_secret_credentials_on_lookup_digest         (lookup_digest)
#  index_operator_secret_credentials_on_public_id             (public_id) UNIQUE
#  index_operator_secret_credentials_on_staff_id              (staff_id)
#  index_operator_secret_credentials_on_staff_secret_kind_id  (staff_secret_kind_id)
#
# Foreign Keys
#
#  fk_rails_...                              (staff_id => operators.id)
#  fk_rails_...                              (staff_identity_secret_status_id => operator_secret_credential_statuses.id)
#  fk_staff_secrets_on_staff_secret_kind_id  (staff_secret_kind_id => operator_secret_credential_kinds.id)
#

class OperatorSecretCredential < OrgPrincipalRecord
  include Retainable

  alias_attribute :staff_secret_status_id, :staff_identity_secret_status_id
  include ::PublicId
  include ::SecretCredential
  include OperatorSecretCredentialKinds

  MAX_SECRETS_PER_STAFF = 20
  SIGN_IN_ALLOWED_STATUS_IDS = [OperatorSecretCredentialStatus::ACTIVE].freeze
  SIGN_IN_ALLOWED_KIND_IDS = OperatorSecretCredentialKind::ALLOWED_FOR_SECRET_SIGN_IN
  attr_accessor :raw_secret_credential

  attribute :staff_identity_secret_status_id, default: OperatorSecretCredentialStatus::ACTIVE
  attribute :staff_secret_kind_id, default: OperatorSecretCredentialKind::LOGIN

  belongs_to :staff, class_name: "Operator"
  belongs_to :staff_secret_credential_status, class_name: "OperatorSecretCredentialStatus",
                                              inverse_of: :staff_secret_credentials,
                                              foreign_key: :staff_identity_secret_status_id
  belongs_to :staff_secret_credential_kind, class_name: "OperatorSecretCredentialKind",
                                            inverse_of: :staff_secret_credentials,
                                            foreign_key: :staff_secret_kind_id

  validates :staff_identity_secret_status_id, numericality: { only_integer: true }
  validates :staff_secret_kind_id, numericality: { only_integer: true }
  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :staff,
                 association: :staff_secret_credentials,
                 foreign_key: :staff_id,
                 limit: :MAX_SECRETS_PER_STAFF,
                 record_name: "secret_credentials",
                 owner_name: "staff"

  scope :allowed_for_secret_credential_sign_in, lambda {
    where(
      staff_identity_secret_status_id: SIGN_IN_ALLOWED_STATUS_IDS,
      staff_secret_kind_id: SIGN_IN_ALLOWED_KIND_IDS,
    )
  }

  def self.identity_secret_credential_status_class
    OperatorSecretCredentialStatus
  end

  def self.identity_secret_credential_status_id_column
    :staff_identity_secret_status_id
  end

  def self.generate_raw_secret_credential(length: SECRET_PASSWORD_LENGTH)
    SecureRandom.base58(length)
  end

  def to_param
    public_id
  end

  def usable_for_secret_credential_sign_in?(now: Time.current)
    return false unless sign_in_status_allowed?
    return false unless sign_in_kind_allowed?
    return false if expired_for_secret_credential_sign_in?(now)

    true
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
      save!
    end

    true
  end

  private

  def sign_in_status_allowed?
    SIGN_IN_ALLOWED_STATUS_IDS.include?(staff_secret_status_id)
  end

  def sign_in_kind_allowed?
    SIGN_IN_ALLOWED_KIND_IDS.include?(staff_secret_kind_id)
  end

  def expired_for_secret_credential_sign_in?(now)
    if respond_to?(:expires_at) && expires_at.present?
      return now > expires_at
    end

    return false if discard_at.nil?
    return false if discard_at.respond_to?(:infinite?) && discard_at.infinite?

    now > discard_at
  end
end
