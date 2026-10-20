# frozen_string_literal: true

module Publishing
  module News
    module App
      class Publication < PublishingRecord
        self.table_name = "publishing_news_app_publications"
        include PublishingPublicationRecord

        validates :created_by_operator_public_id, :ended_by_operator_public_id, length: { maximum: 21 }
      end
    end
  end
end
