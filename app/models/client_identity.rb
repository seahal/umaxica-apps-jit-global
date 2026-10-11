# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_identities
# Database name: app_zenith
#
#  id                    :bigint           not null, primary key
#  audience              :string           not null
#  issuer                :string           not null
#  last_authenticated_at :datetime
#  lock_version          :integer          default(0), not null
#  subject               :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  public_id             :string           default(""), not null
#  source_record_id      :bigint           not null
#  status_id             :bigint           default(0), not null
#
# Indexes
#
#  index_client_identities_on_issuer_and_subject_and_audience  (issuer,subject,audience) UNIQUE
#  index_client_identities_on_public_id                        (public_id) UNIQUE
#  index_client_identities_on_source_record_id                 (source_record_id) UNIQUE
#  index_client_identities_on_status_id                        (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => client_identity_states.id)
#
class ClientIdentity < AppRpRecord
  include ::PublicId

  belongs_to :identity_state,
             class_name: "ClientIdentityState",
             foreign_key: :status_id,
             inverse_of: :client_identities
  has_one :client_persona,
          class_name: "ClientPersona",
          dependent: :restrict_with_error,
          inverse_of: :client_identity
  has_many :persona_assignments, dependent: :destroy, inverse_of: :client_identity

  validates :issuer, :subject, :audience, :source_record_id, presence: true
  validates :public_id, uniqueness: true
  validates :source_record_id, uniqueness: true
  validates :subject, uniqueness: { scope: %i(issuer audience) }
end
