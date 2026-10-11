# typed: false
# frozen_string_literal: true

# Surface-local serialization row for org authority quota and ownership writes.
class OperatorAuthorityLock < OrgRpRecord
  belongs_to :operator, inverse_of: :authority_lock

  class << self
    public

    def acquire_for!(operator_id:)
      create_or_find_by!(operator_id:)
      lock.find_by!(operator_id:)
    end
  end
end
