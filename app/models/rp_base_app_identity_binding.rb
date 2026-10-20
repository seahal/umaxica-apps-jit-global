# typed: false
# frozen_string_literal: true

class RpBaseAppIdentityBinding < RpBaseAppRecord
  self.table_name = "rp_identity_bindings"

  CELL = RpCellBinding.fetch("rp_base_app")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  belongs_to :principal, class_name: "RpBaseAppPrincipal", inverse_of: :identity_bindings
  has_many :op_session_bindings, class_name: "RpBaseAppOpSessionBinding", foreign_key: :identity_binding_id,
                                 inverse_of: :identity_binding,
                                 dependent: :restrict_with_error

  validates :issuer, :realm, :client_id, :subject, presence: true
  validates :subject, uniqueness: { scope: %i(issuer realm client_id) }, on: :create
  validates :realm, inclusion: { in: [REALM] }
  validates :client_id, inclusion: { in: [CLIENT_ID] }
  validate :identity_attributes_are_immutable
  validates :realm, length: { maximum: 3 }
  validates :client_id, length: { maximum: 64 }
  validates :issuer, :subject, length: { maximum: 255 }

  private

  def identity_attributes_are_immutable
    return unless persisted?

    %i(issuer realm client_id subject principal_id).each do |attribute|
      errors.add(attribute, "cannot be changed after creation") if will_save_change_to_attribute?(attribute)
    end
  end
end
