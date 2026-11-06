# frozen_string_literal: true

class ValidateClientSocialLinkSourceReceiptForeignKey < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:client_social_link_source_receipts, :client_external_identities)
  end
end
