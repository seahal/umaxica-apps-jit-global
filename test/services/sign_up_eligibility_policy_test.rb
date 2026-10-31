# typed: false
# frozen_string_literal: true

require "test_helper"

# ADR `sign-up-one-day-minimum-age-and-feature-level-age-restrictions`: sign-up establishes
# identity, not age. Eligibility is the explicit one-day rule alone, shared by `.app` and `.org`.
class SignUpEligibilityPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the one-day boundary follows the calendar before on and after leap day" do
    [Date.new(2024, 2, 28), Date.new(2024, 2, 29), Date.new(2024, 3, 1)].each do |today|
      %i(app org).each do |surface|
        assert SignUpEligibilityPolicy.eligible?((today - 1).iso8601, surface: surface, today: today)
        assert_not SignUpEligibilityPolicy.eligible?(today.iso8601, surface: surface, today: today)
        assert_not SignUpEligibilityPolicy.eligible?((today + 1).iso8601, surface: surface, today: today)
        assert SignUpEligibilityPolicy.eligible?("2011-03-01", surface: surface, today: today)
      end
    end
  end

  test "the closest eligible birthdate is yesterday and today is refused" do
    today = Date.new(2026, 6, 25)

    assert_not SignUpEligibilityPolicy.eligible?("2026-06-25", surface: :app, today: today)
    assert_not SignUpEligibilityPolicy.eligible?("2026-06-26", surface: :app, today: today)
    assert SignUpEligibilityPolicy.eligible?("2026-06-24", surface: :app, today: today)
    assert SignUpEligibilityPolicy.eligible?("2000-06-25", surface: :app, today: today)
  end

  test "the refusal moves with the service date without an age threshold" do
    birthdate = "2026-06-24"

    assert_not SignUpEligibilityPolicy.eligible?(birthdate, surface: :app, today: Date.new(2026, 6, 24))
    assert_not SignUpEligibilityPolicy.eligible?(birthdate, surface: :app, today: Date.new(2026, 6, 23))
    assert SignUpEligibilityPolicy.eligible?(birthdate, surface: :app, today: Date.new(2026, 6, 25))
  end

  test "the same one-day rule applies to the org surface without raising" do
    today = Date.new(2026, 6, 25)

    assert_not SignUpEligibilityPolicy.eligible?("2026-06-25", surface: :org, today: today)
    assert SignUpEligibilityPolicy.eligible?("2026-06-24", surface: :org, today: today)
  end

  test "an unsupported surface is refused instead of guessed" do
    error =
      assert_raises(ArgumentError) do
        SignUpEligibilityPolicy.eligible?("2026-06-24", surface: :com, today: Date.new(2026, 6, 25))
      end

    assert_equal "unsupported sign-up eligibility surface: :com", error.message
  end

  test "surface validation rejects missing empty and non-string inputs explicitly" do
    [nil, "", 0, [], :com].each do |surface|
      assert_not SignUpEligibilityPolicy.supported_surface?(surface)
      assert_raises(ArgumentError) do
        SignUpEligibilityPolicy.eligible?("2026-06-24", surface: surface, today: Date.new(2026, 6, 25))
      end
    end

    assert SignUpEligibilityPolicy.supported_surface?("app")
    assert SignUpEligibilityPolicy.supported_surface?(:org)
  end

  test "an unparseable birthdate is not eligible" do
    assert_not SignUpEligibilityPolicy.eligible?("not-a-date", surface: :app)
    assert_not SignUpEligibilityPolicy.eligible?("", surface: :app)
    assert_not SignUpEligibilityPolicy.eligible?(nil, surface: :app)
  end
end
