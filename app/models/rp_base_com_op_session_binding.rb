# typed: false
# frozen_string_literal: true

class RpBaseComOpSessionBinding < RpBaseComRecord
  self.table_name = "rp_op_session_bindings"

  CELL = RpCellBinding.fetch("rp_base_com")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  belongs_to :identity_binding, class_name: "RpBaseComIdentityBinding", inverse_of: :op_session_bindings,
                                optional: true
  has_many :sessions, class_name: "RpBaseComSession", foreign_key: :op_session_binding_id,
                      inverse_of: :op_session_binding,
                      dependent: :restrict_with_error
  has_many :event_receipts, class_name: "RpBaseComEventReceipt", foreign_key: :op_session_binding_id,
                            inverse_of: :op_session_binding,
                            dependent: :restrict_with_error

  validates :issuer, :realm, :client_id, :sid, presence: true
  validates :sid, uniqueness: { scope: %i(issuer realm client_id) }, on: :create
  validates :realm, inclusion: { in: [REALM] }
  validates :client_id, inclusion: { in: [CLIENT_ID] }
  validates :realm, length: { maximum: 3 }
  validates :client_id, length: { maximum: 64 }
  validates :issuer, :sid, length: { maximum: 255 }

  public

  def revoked?
    revoked_at.present?
  end

  def revoke!(now: self.class.database_now)
    with_lock do
      update!(revoked_at: revoked_at || now)
    end
    self
  end
end
