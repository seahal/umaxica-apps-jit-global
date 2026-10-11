# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: persona_assignments
# Database name: app_zenith
#
#  id                 :bigint           not null, primary key
#  assigned_at        :datetime         not null
#  revoked_at         :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  client_identity_id :bigint           not null
#  persona_id         :bigint           not null
#  public_id          :string           not null
#
# Indexes
#
#  index_persona_assignments_on_client_identity_id                 (client_identity_id)
#  index_persona_assignments_on_persona_id                          (persona_id)
#  index_persona_assignments_on_public_id                           (public_id) UNIQUE
#  idx_persona_assignments_one_active_identity_per_persona         (persona_id,client_identity_id) UNIQUE WHERE (revoked_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (client_identity_id => client_identities.id)
#  fk_rails_...  (persona_id => personas.id)
#
class PersonaAssignment < AppRpRecord
  include ::AccountAssignment

  belongs_to :persona, class_name: "ClientPersona", inverse_of: :persona_assignments
  belongs_to :client_identity, inverse_of: :persona_assignments
end
