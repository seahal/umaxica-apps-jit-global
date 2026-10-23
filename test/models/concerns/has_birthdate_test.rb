# typed: false
# frozen_string_literal: true

require "test_helper"

class HasBirthdateTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  MODEL_CLASSES = [Operator, Visitor, Client].freeze

  setup do
    Prosopite.pause do
      OperatorStatus.ensure_defaults!
      OperatorVisibility.ensure_defaults!
      OperatorMfaStatus.ensure_defaults!

      VisitorStatus.ensure_defaults!
      VisitorVisibility.ensure_defaults!
      VisitorMfaStatus.ensure_defaults!

      ClientStatus.ensure_defaults!
      ClientVisibility.ensure_defaults!
      ClientMfaStatus.ensure_defaults!
    end
  end

  test "target actor models include the concern" do
    MODEL_CLASSES.each do |model_class|
      assert_includes model_class.included_modules, HasBirthdate, "#{model_class} should include HasBirthdate"
    end
  end

  test "nil birthdate is valid" do
    assert_birthdate_valid(nil)
  end

  test "blank birthdate is valid" do
    assert_birthdate_valid("")
  end

  test "zero-padded ISO date is valid" do
    assert_birthdate_valid("2000-02-03")
  end

  test "calendar-invalid zero-padded date is valid as input" do
    assert_birthdate_valid("2000-02-30")
    assert_birthdate_valid("1900-02-29")
    assert_birthdate_valid("2000-04-31")
  end

  test "birthdate validation requires both accepted format and date before today" do
    travel_to Time.zone.local(2024, 5, 18, 12, 0, 0) do
      assert_birthdate_invalid("1899-12-31", error: :birthdate_format) # before today but outside format domain
      assert_birthdate_invalid("2024-05-18", error: :birthdate_before_today) # accepted format but not before today
      assert_birthdate_invalid("2024-05-19", error: :birthdate_before_today) # accepted format but future
      assert_birthdate_valid("2024-05-17") # accepted format and before today
    end
  end

  test "today and future dates are invalid after format passes" do
    travel_to Time.zone.local(2024, 5, 18, 12, 0, 0) do
      assert_birthdate_invalid("2024-05-18", error: :birthdate_before_today)
      assert_birthdate_invalid("2024-05-19", error: :birthdate_before_today)
    end
  end

  test "dates before today are valid" do
    travel_to Time.zone.local(2024, 5, 18, 12, 0, 0) do
      assert_birthdate_valid("2024-05-17")
    end
  end

  test "plain birthdate length is limited to ten characters" do
    assert_birthdate_invalid("2" * 1000)
  end

  test "parsed_birthdate returns Date for a calendar-valid date" do
    each_birthdate_record("2000-02-03") do |record|
      assert_equal Date.new(2000, 2, 3), record.parsed_birthdate
    end
  end

  test "parsed_birthdate returns nil for a calendar-invalid date" do
    each_birthdate_record("2000-02-30") do |record|
      assert_nil record.parsed_birthdate
    end
  end

  test "calendar_valid_birthdate? reflects parseability" do
    each_birthdate_record("2000-02-03") do |record|
      assert_predicate record, :calendar_valid_birthdate?
    end

    each_birthdate_record("2000-02-30") do |record|
      assert_not record.calendar_valid_birthdate?
    end
  end

  test "age_on returns age around the birthday" do
    each_birthdate_record("2000-06-15") do |record|
      assert_equal 23, record.age_on(Date.new(2024, 6, 14))
      assert_equal 24, record.age_on(Date.new(2024, 6, 15))
      assert_equal 24, record.age_on(Date.new(2024, 6, 16))
    end
  end

  test "age_on returns nil when birthdate is blank" do
    each_birthdate_record(nil) do |record|
      assert_nil record.age_on
    end
  end

  test "age_on returns nil for calendar-invalid birthdate" do
    each_birthdate_record("2000-02-30") do |record|
      assert_equal 24, record.age_on(Date.new(2024, 6, 15))
    end
  end

  test "age_on uses rollover date for structurally valid calendar overflow" do
    each_birthdate_record("2000-02-31") do |record|
      assert_equal Date.new(2000, 3, 1), record.birthdate_for_age
      assert_equal 23, record.age_on(Date.new(2024, 2, 29))
      assert_equal 24, record.age_on(Date.new(2024, 3, 1))
    end
  end

  test "minimum_age_reached? uses canonical birthdate advance boundary" do
    each_birthdate_record("2011-02-28") do |record|
      assert record.minimum_age_reached?(13, today: Date.new(2024, 2, 28))
    end

    each_birthdate_record("2011-03-01") do |record|
      assert_not record.minimum_age_reached?(13, today: Date.new(2024, 2, 29))
    end
  end

  test "minimum_age_reached? uses canonical leap day advance in non leap year" do
    each_birthdate_record("2012-02-29") do |record|
      assert_not record.minimum_age_reached?(13, today: Date.new(2025, 2, 27))
      assert record.minimum_age_reached?(13, today: Date.new(2025, 2, 28))
      assert_not record.adult_for_nsfw?(minimum_age: 18, today: Date.new(2030, 2, 27))
      assert record.adult_for_nsfw?(minimum_age: 18, today: Date.new(2030, 2, 28))
    end
  end

  test "adult_for_nsfw? is true at or above the minimum age" do
    each_birthdate_record("2006-05-18") do |record|
      assert record.adult_for_nsfw?(minimum_age: 18, today: Date.new(2024, 5, 18))
    end
  end

  test "adult_for_nsfw? is false under the minimum age" do
    each_birthdate_record("2006-05-19") do |record|
      assert_not record.adult_for_nsfw?(minimum_age: 18, today: Date.new(2024, 5, 18))
    end
  end

  test "adult_for_nsfw? is false for calendar-invalid birthdate" do
    each_birthdate_record("2000-01-32") do |record|
      assert_not record.adult_for_nsfw?(minimum_age: 18, today: Date.new(2024, 5, 18))
    end
  end

  test "nsfw_unlockable? uses canonical age birthdate for structurally valid adult birthdate" do
    each_birthdate_record("2000-02-03") do |record|
      assert_predicate record, :nsfw_unlockable?
    end

    each_birthdate_record("2000-02-30") do |record|
      assert_predicate record, :nsfw_unlockable?
    end

    each_birthdate_record(nil) do |record|
      assert_not record.nsfw_unlockable?
    end
  end

  test "birthdate is encrypted at rest and readable after reload" do
    MODEL_CLASSES.each do |model_class|
      record = model_class.create!(security_mode_id: SecurityModeConfigurable::NORMAL, birthdate: "2000-02-03")
      raw_value = raw_birthdate_for(record)

      assert_equal "2000-02-03", record.reload.birthdate, "#{model_class} should decrypt birthdate after reload"
      assert_not_equal "2000-02-03", raw_value, "#{model_class} should store encrypted birthdate"
    end
  end

  private

  def assert_birthdate_valid(value)
    each_birthdate_record(value) do |record|
      assert_predicate record, :valid?, "#{record.class} should accept #{value.inspect}: #{record.errors.full_messages}"
    end
  end

  def assert_birthdate_invalid(value, error: nil)
    each_birthdate_record(value) do |record|
      assert_not record.valid?, "#{record.class} should reject #{value.inspect}"
      assert_predicate record.errors[:birthdate], :present?, "#{record.class} should add a birthdate error"
      assert_includes record.errors.details[:birthdate].map { |detail| detail.fetch(:error) }, error if error
    end
  end

  def each_birthdate_record(value)
    MODEL_CLASSES.each do |model_class|
      yield model_class.new(birthdate: value, security_mode_id: SecurityModeTestDefault.id_for(model_class))
    end
  end

  def raw_birthdate_for(record)
    table_name = record.class.connection.quote_table_name(record.class.table_name)
    primary_key = record.class.connection.quote_column_name(record.class.primary_key)
    sql = "SELECT birthdate FROM #{table_name} WHERE #{primary_key} = :id"
    sanitized_sql = record.class.sanitize_sql_array([sql, { id: record.id }])

    record.class.connection.execute(sanitized_sql).first.fetch("birthdate")
  end
end
