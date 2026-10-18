# typed: false
# frozen_string_literal: true

require "test_helper"

class TimezoneIdentifierTest < ActiveSupport::TestCase
  test "normalize folds the short aliases carried in the tz parameter and cookie" do
    assert_equal "Asia/Tokyo", TimezoneIdentifier.normalize("jst")
    assert_equal "Asia/Tokyo", TimezoneIdentifier.normalize("asia/tokyo")
    assert_equal "Asia/Tokyo", TimezoneIdentifier.normalize("Asia/Tokyo")
    assert_equal "Etc/UTC", TimezoneIdentifier.normalize("utc")
    assert_equal "Etc/UTC", TimezoneIdentifier.normalize("etc/utc")
  end

  test "normalize returns the canonical IANA name for other known zones" do
    assert_equal "America/New_York", TimezoneIdentifier.normalize("America/New_York")
    assert_equal "America/New_York", TimezoneIdentifier.normalize("  America/New_York  ")
    assert_equal "Europe/Paris", TimezoneIdentifier.normalize("Paris")
  end

  # The tz query parameter and the preference cookie are downcased in transit,
  # so a lowercase IANA name has to resolve to the same zone as the canonical
  # spelling; ActiveSupport::TimeZone[] alone rejects it.
  test "normalize matches identifiers case-insensitively" do
    assert_equal "America/New_York", TimezoneIdentifier.normalize("america/new_york")
    assert_equal "Europe/Paris", TimezoneIdentifier.normalize("EUROPE/PARIS")
    assert_equal "Asia/Tokyo", TimezoneIdentifier.normalize("tokyo")
  end

  test "normalize rejects unknown values instead of passing them through" do
    assert_nil TimezoneIdentifier.normalize("Invalid/Zone")
    assert_nil TimezoneIdentifier.normalize("asia/tokyo; DROP")
    assert_nil TimezoneIdentifier.normalize("")
    assert_nil TimezoneIdentifier.normalize(nil)
  end

  test "valid? reports whether a value names a real zone" do
    assert TimezoneIdentifier.valid?("jst")
    assert_not TimezoneIdentifier.valid?("Invalid/Zone")
  end

  test "resolve takes the first usable candidate" do
    assert_equal "Etc/UTC", TimezoneIdentifier.resolve(nil, "Invalid/Zone", "utc", "jst")
  end

  test "resolve falls back only to the default the caller names" do
    assert_equal TimezoneIdentifier::DEFAULT, TimezoneIdentifier.resolve("Invalid/Zone")
    assert_equal "Etc/UTC", TimezoneIdentifier.resolve(nil, default: "Etc/UTC")
  end

  test "standard_utc_offset reports the non-DST offset in seconds" do
    assert_equal 0, TimezoneIdentifier.standard_utc_offset("Etc/UTC")
    assert_equal 9 * 3600, TimezoneIdentifier.standard_utc_offset("Asia/Tokyo")
    assert_equal(-5 * 3600, TimezoneIdentifier.standard_utc_offset("America/New_York"))
    assert_equal(-10 * 3600, TimezoneIdentifier.standard_utc_offset("Pacific/Honolulu"))
    assert_nil TimezoneIdentifier.standard_utc_offset("Invalid/Zone")
  end

  test "utc_offset_sort_key orders negative, zero and positive offsets ascending" do
    zones = %w(Asia/Tokyo America/New_York Etc/UTC Pacific/Honolulu America/Los_Angeles)

    ordered = zones.sort_by { |zone| TimezoneIdentifier.utc_offset_sort_key(zone) }

    assert_equal(
      %w(Pacific/Honolulu America/Los_Angeles America/New_York Etc/UTC Asia/Tokyo),
      ordered,
    )
  end

  test "utc_offset_sort_key breaks an offset tie on the canonical identifier" do
    # Both are UTC-5 standard; the identifier decides the order deterministically.
    tie = %w(America/Toronto America/New_York)

    assert_equal(
      %w(America/New_York America/Toronto),
      tie.sort_by { |zone| TimezoneIdentifier.utc_offset_sort_key(zone) },
    )
    assert_equal(
      TimezoneIdentifier.standard_utc_offset("America/New_York"),
      TimezoneIdentifier.standard_utc_offset("America/Toronto"),
    )
  end

  test "standard_utc_offset ignores daylight saving so the picker order cannot flip seasonally" do
    # America/Los_Angeles observes UTC-7 in summer, but its standard offset is always UTC-8.
    assert_equal(-8 * 3600, TimezoneIdentifier.standard_utc_offset("America/Los_Angeles"))
    # America/Phoenix never observes DST; it stays UTC-7 and therefore sorts after Los Angeles
    # all year.
    assert_equal(-7 * 3600, TimezoneIdentifier.standard_utc_offset("America/Phoenix"))
    assert_equal(
      -1,
      TimezoneIdentifier.utc_offset_sort_key("America/Los_Angeles") <=>
        TimezoneIdentifier.utc_offset_sort_key("America/Phoenix"),
    )
  end
end
