# typed: false
# frozen_string_literal: true

class EnterpriseDelegationGrant < AppRpRecord
  belongs_to :enterprise, inverse_of: :delegation_grants
  belongs_to :client, inverse_of: :enterprise_delegation_grants
end
