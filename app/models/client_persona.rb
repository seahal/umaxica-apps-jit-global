# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: personas
# Database name: app_zenith
#
# The physical table remains `personas` for the naming migration. The concrete
# Ruby model is ClientPersona; Persona is the common interface concern.
class ClientPersona < AppRpRecord
  self.table_name = "personas"

  include ::Persona

  persona_interface_validations

  belongs_to :client_identity, inverse_of: :client_persona
  has_many :persona_assignments, dependent: :destroy, inverse_of: :persona
  has_many :persona_memberships, dependent: :destroy, inverse_of: :persona
  has_one :ownership,
          class_name: "ClientPersonaOwnership",
          dependent: :restrict_with_error,
          inverse_of: :client_persona
  has_one :owner, through: :ownership, source: :client
  has_many :administration_grants,
           class_name: "ClientPersonaAdministrationGrant",
           dependent: :restrict_with_error,
           inverse_of: :client_persona
  has_many :delegation_grants,
           class_name: "ClientPersonaDelegationGrant",
           dependent: :restrict_with_error,
           inverse_of: :client_persona
  has_many :usage_grants,
           class_name: "ClientPersonaUsageGrant",
           dependent: :restrict_with_error,
           inverse_of: :client_persona
  has_many :view_grants,
           class_name: "ClientPersonaViewGrant",
           dependent: :restrict_with_error,
           inverse_of: :client_persona
  has_many :ownership_transfer_requests,
           class_name: "ClientPersonaOwnershipTransferRequest",
           dependent: :restrict_with_error,
           inverse_of: :client_persona
  has_one :avatar_persona_binding,
          class_name: "AvatarPersonaBinding",
          dependent: :destroy,
          inverse_of: :persona

  validates :client_identity_id, uniqueness: true

  public

  def current_avatar_persona_binding
    return nil unless persisted?

    AvatarPersonaBinding.active.find_by(persona_id: id)
  end

  def current_avatar
    current_avatar_persona_binding&.avatar
  end
end
