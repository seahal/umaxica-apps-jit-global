# frozen_string_literal: true

# One validated display snapshot supplies all three com preference cookies.
class PreferenceDisplayValue
  attr_reader :preferences, :language, :experience

  public

  def initialize(preferences)
    unless SecurityJwtPreferenceTokenCodec.valid_display_snapshot?(preferences)
      raise ArgumentError, "invalid anonymous preference snapshot"
    end

    @preferences = preferences.transform_values { |value| value.dup.freeze }.freeze
    @language = @preferences.fetch("language")
    @experience = @preferences.except("language").to_json.freeze
    freeze
  end
end
