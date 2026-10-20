# typed: false
# frozen_string_literal: true

class OpOrgProtocolEpoch < OpBaseOrgRecord
  self.table_name = "op_protocol_epochs"

  REALM = "org"

  validates :id, inclusion: { in: [1] }, allow_nil: true
  validates :realm, inclusion: { in: [REALM] }, presence: true
  validates :contract_epoch, numericality: { only_integer: true, greater_than: 0 }, presence: true
  validates :changed_at, presence: true
  validates :realm, length: { maximum: 3 }

  class << self
    public

    # The realm OP's single persisted contract epoch, stamped on new roots, grants and Access JWTs.
    def current_contract_epoch
      find(1).contract_epoch
    end
  end
end
