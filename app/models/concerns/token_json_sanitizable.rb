# typed: false
# frozen_string_literal: true

module TokenJsonSanitizable
  extend ActiveSupport::Concern

  def as_json(options = {})
    options[:except] =
      Array(options[:except]) | %i(id refresh_token_digest refresh_token_family_id refresh_token_generation)
    super
  end
end
