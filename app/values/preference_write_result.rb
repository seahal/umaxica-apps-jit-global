# frozen_string_literal: true

# Completed signed issuance, held until the setting transaction commits.
PreferenceWriteResult =
  Data.define(:token, :decoded, :display, :expires_at) do
    public

    def initialize(token:, decoded:, display:, expires_at:)
      claims = decoded.transform_values do |value|
        value.is_a?(Hash) ? value.transform_values { |item| item.dup.freeze }.freeze : value.dup.freeze
      end.freeze
      super(token: token.dup.freeze, decoded: claims, display: display, expires_at: expires_at.dup.freeze)
    end
  end
