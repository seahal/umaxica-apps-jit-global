# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_secret_credentials
# Database name: com_principal
#
#  id                                  :bigint           not null, primary key
#  consumed_at                         :datetime
#  delivery_method                     :string
#  discard_at                        :datetime         default(Infinity), not null
#  failure_count                       :integer          default(0), not null
#  issued_at                           :datetime
#  issued_by_ref                       :string
#  issued_by_type                      :string
#  last_failed_at                      :datetime
#  last_used_at                        :datetime
#  locked_at                           :datetime
#  lookup_digest                       :string
#  max_failures                        :integer
#  max_uses                            :integer
#  name                                :string           default(""), not null
#  not_before_at                       :datetime
#  password_digest                     :string           default(""), not null
#  purge_eligible_at                           :datetime         default(Infinity), not null
#  revoked_at                          :datetime
#  safe_prefix                         :string
#  scope                               :string
#  secret_kind                         :string
#  usage_policy                        :string
#  use_count                           :integer          default(0), not null
#  uses_remaining                      :integer          default(1), not null
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  issued_by_id                        :bigint
#  public_id                           :string(21)       not null
#  visitor_id                          :bigint           not null
#  visitor_secret_credential_kind_id   :bigint           default(1), not null
#  visitor_secret_credential_status_id :bigint           default(1), not null
#
# Indexes
#
#  idx_on_visitor_secret_credential_kind_id_80c2fa07fe    (visitor_secret_credential_kind_id)
#  idx_on_visitor_secret_credential_status_id_a8132e5a1a  (visitor_secret_credential_status_id)
#  index_visitor_secret_credentials_on_lookup_digest      (lookup_digest)
#  index_visitor_secret_credentials_on_public_id          (public_id) UNIQUE
#  index_visitor_secret_credentials_on_visitor_id         (visitor_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_id => visitors.id)
#  fk_rails_...  (visitor_secret_credential_kind_id => visitor_secret_credential_kinds.id)
#  fk_rails_...  (visitor_secret_credential_status_id => visitor_secret_credential_statuses.id)
#
class VisitorSecretCredential < ComPrincipalRecord
  include Retainable
  include PublicId
  include SecretCredential
  include VisitorSecretCredentialKinds

  MAX_SECRETS_PER_VISITOR = 20
  ACTIVE_STATUS_IDS = [VisitorSecretCredentialStatus::ACTIVE].freeze

  attr_accessor :raw_secret_credential

  attribute :visitor_secret_credential_status_id, default: VisitorSecretCredentialStatus::ACTIVE
  attribute :visitor_secret_credential_kind_id, default: VisitorSecretCredentialKind::LOGIN

  belongs_to :visitor, inverse_of: :visitor_secret_credentials
  belongs_to :visitor_secret_credential_status, inverse_of: :visitor_secret_credentials
  belongs_to :visitor_secret_credential_kind, inverse_of: :visitor_secret_credentials

  validates :name, length: { maximum: 255 }
  validates :password_digest, presence: true, length: { maximum: 255 }
  validates :visitor_secret_credential_status_id, numericality: { only_integer: true }
  validates :visitor_secret_credential_kind_id, numericality: { only_integer: true }
  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :visitor,
                 association: :visitor_secret_credentials,
                 foreign_key: :visitor_id,
                 limit: :MAX_SECRETS_PER_VISITOR,
                 record_name: "secret_credentials",
                 owner_name: "visitor"
  validates_with RecoveryIdentityRequiredValidator,
                 on: :create,
                 owner: :visitor,
                 message: Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE

  def self.identity_secret_credential_status_class
    VisitorSecretCredentialStatus
  end

  def self.identity_secret_credential_status_id_column
    :visitor_secret_credential_status_id
  end

  def self.generate_raw_secret_credential(length: SECRET_PASSWORD_LENGTH)
    SecureRandom.base58(length)
  end

  def value=(val)
    self.password = val
  end

  def value
    password
  end

  def to_param
    public_id
  end

end
