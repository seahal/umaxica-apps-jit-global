# typed: false
# frozen_string_literal: true

# R5 cell-local authentication state. The connection is fixed by the boot-time role binding.
class RpBaseOrgRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :rp_base_org, reading: :rp_base_org_replica }
end
