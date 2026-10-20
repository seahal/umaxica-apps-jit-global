# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class Publication < PublishingRecord
        self.table_name = "publishing_info_com_publications"
        include PublishingPublicationRecord

        validates :created_by_operator_public_id, :ended_by_operator_public_id, length: { maximum: 21 }
      end
    end
  end
end
