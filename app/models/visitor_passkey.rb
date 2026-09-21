# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_passkeys
# Database name: com_zenith
#
#  id                       :bigint           not null, primary key
#  aaguid                   :uuid
#  authenticator_attachment :string
#  backup_eligible          :boolean
#  backup_state             :boolean
#  description              :string           default(""), not null
#  discard_at             :datetime         default(Infinity), not null
#  last_used_at             :datetime
#  metadata_source          :string
#  provider_name            :string
#  public_key               :text             not null
#  purge_eligible_at                :datetime         default(Infinity), not null
#  sign_count               :bigint           default(0), not null
#  transports               :jsonb
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  external_id              :uuid             not null
#  public_id                :string(21)       not null
#  status_id                :bigint           default(1), not null
#  visitor_id               :bigint           not null
#  webauthn_id              :string           default(""), not null
#
# Indexes
#
#  index_visitor_passkeys_on_discard_at  (discard_at)
#  index_visitor_passkeys_on_public_id     (public_id) UNIQUE
#  index_visitor_passkeys_on_purge_eligible_at     (purge_eligible_at)
#  index_visitor_passkeys_on_status_id     (status_id)
#  index_visitor_passkeys_on_visitor_id    (visitor_id)
#  index_visitor_passkeys_on_webauthn_id   (webauthn_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (status_id => visitor_passkey_statuses.id)
#  fk_rails_...  (visitor_id => visitors.id)
#
class VisitorPasskey < ComPrincipalRecord
  include PublicId
  include Retainable
  include MfaStatusCredential

  MAX_PASSKEYS_PER_VISITOR = 4

  attribute :status_id, default: VisitorPasskeyStatus::ACTIVE

  belongs_to :visitor, inverse_of: :visitor_passkeys
  mfa_status_owner :visitor
  belongs_to :status, class_name: "VisitorPasskeyStatus"

  scope :active, -> { where(status_id: VisitorPasskeyStatus::ACTIVE) }

  validates :webauthn_id, presence: true, uniqueness: true
  validates :external_id, presence: true
  validates :public_key, presence: true
  validates :description, presence: true
  validates :status_id, numericality: { only_integer: true }
  validates :sign_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :visitor,
                 association: :visitor_passkeys,
                 foreign_key: :visitor_id,
                 limit: :MAX_PASSKEYS_PER_VISITOR,
                 record_name: "passkeys",
                 owner_name: "visitor"
  validates_with RecoveryIdentityRequiredValidator,
                 on: :create,
                 owner: :visitor,
                 message: Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE

  before_validation :set_defaults, on: :create

  def to_param
    public_id
  end

  private

  def set_defaults
    self.external_id ||= SecureRandom.uuid
    self.sign_count ||= 0
    self.description = I18n.t("sign.default_passkey_description") if description.blank?
  end
end
