# frozen_string_literal: true

require "test_helper"

class PreferenceDisplayValueTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a display snapshot copies values and emits matching language and experience" do
    source = {
      "theme" => "dark",
      "language" => +"ja",
      "timezone" => "Asia/Tokyo",
      "currency" => "jpy",
      "date_format" => "iso",
      "time_format" => "24",
      "motion" => "standard",
      "density" => "standard",
      "page_size" => "infinity",
    }
    display = PreferenceDisplayValue.new(source)
    source.fetch("language").replace("en")
    source["theme"] = "light"

    assert_equal "ja", display.language
    assert_equal "dark", JSON.parse(display.experience).fetch("theme")
    assert_not JSON.parse(display.experience).key?("language")
    assert_raises(FrozenError) { display.preferences.fetch("language").replace("en") }
    assert_raises(FrozenError) { display.preferences["theme"] = "light" }
  end

  test "a display snapshot rejects missing and unsupported values" do
    assert_raises(ArgumentError) { PreferenceDisplayValue.new({}) }
    assert_raises(ArgumentError) { PreferenceDisplayValue.new(nil) }
  end
end
