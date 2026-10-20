# frozen_string_literal: true

module Publishing
  module Help
    module Org
      class Publication < PublishingRecord
        self.table_name = "publishing_help_org_publications"
        include PublishingPublicationRecord

        validates :created_by_operator_public_id, :ended_by_operator_public_id, length: { maximum: 21 }
      end
    end
  end
end
