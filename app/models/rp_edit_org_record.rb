# typed: false
# frozen_string_literal: true

# R5 cell-local authentication state. The connection is fixed by the boot-time role binding.
class RpEditOrgRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :rp_edit_org, reading: :rp_edit_org_replica }
end
