# typed: false
# frozen_string_literal: true

class EnterpriseAdministrationGrant < AppRpRecord
  belongs_to :enterprise, inverse_of: :administration_grants
  belongs_to :client, inverse_of: :enterprise_administration_grants
end
