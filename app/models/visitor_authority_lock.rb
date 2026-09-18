# typed: false
# frozen_string_literal: true

# Surface-local serialization row for com authority quota and ownership writes.
class VisitorAuthorityLock < ComRpRecord
  belongs_to :visitor, inverse_of: :authority_lock

  class << self
    public

    def acquire_for!(visitor_id:)
      create_or_find_by!(visitor_id:)
      lock.find_by!(visitor_id:)
    end
  end
end
