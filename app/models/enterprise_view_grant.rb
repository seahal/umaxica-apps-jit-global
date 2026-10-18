# typed: false
# frozen_string_literal: true

class EnterpriseViewGrant < AppRpRecord
  belongs_to :enterprise, inverse_of: :view_grants
  belongs_to :client, inverse_of: :enterprise_view_grants
end
