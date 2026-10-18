# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_identities
# Database name: com_zenith
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
#  index_visitor_identities_on_issuer_and_subject_and_audience  (issuer,subject,audience) UNIQUE
#  index_visitor_identities_on_public_id                        (public_id) UNIQUE
#  index_visitor_identities_on_source_record_id                 (source_record_id) UNIQUE
#  index_visitor_identities_on_status_id                        (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => visitor_identity_states.id)
#
class VisitorIdentity < ComRpRecord
  include ::PublicId

  belongs_to :identity_state,
             class_name: "VisitorIdentityState",
             foreign_key: :status_id,
             inverse_of: :visitor_identities
  has_one :individual, dependent: :restrict_with_error, inverse_of: :visitor_identity
  has_many :individual_assignments, dependent: :destroy, inverse_of: :visitor_identity
  has_many :oidc_identity_bindings, class_name: "VisitorOidcIdentityBinding",
                                    dependent: :restrict_with_error, inverse_of: :visitor_identity

  validates :issuer, :subject, :audience, :source_record_id, presence: true
  validates :public_id, uniqueness: true
  validates :source_record_id, uniqueness: true
  validates :subject, uniqueness: { scope: %i(issuer audience) }
end
