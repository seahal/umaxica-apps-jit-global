# typed: false
# frozen_string_literal: true

# A surface-local serialization row for quota and ownership writes.
#
# Client and the app RP/resource models have different semantic Active Record
# bases but inherit the same app_zenith writer boundary. The row is therefore
# the explicit lock target used by authority operations; it is not an authority
# grant and never answers an authorization question.
class ClientAuthorityLock < AppRpRecord
  belongs_to :client, inverse_of: :authority_lock

  class << self
    public

    def acquire_for!(client_id:)
      # Pass only the unique key. `create_or_find_by!` re-queries with every
      # supplied attribute after a unique violation; timestamps would make an
      # existing lock row impossible to find on the second acquisition.
      create_or_find_by!(client_id:)
      lock.find_by!(client_id:)
    end
  end
end
