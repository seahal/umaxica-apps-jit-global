# typed: false
# frozen_string_literal: true

require "test_helper"

class RetainableTest < ActiveSupport::TestCase
  class DummyRetainable
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include Retainable

    attribute :created_at, :datetime, default: -> { Time.current }

    class << self
      def database_now_value=(value)
        @database_now_value = value
      end

      def database_now
        database_now_value || Time.current
      end

      private

      def database_now_value
        @database_now_value
      end
    end

    # We need to simulate ActiveRecord update context for the validation
    def validation_context
      @validation_context || :default
    end

    attr_writer :validation_context

    # mock update! for schedule_retention!
    def update!(attrs)
      assign_attributes(attrs)
      raise ActiveRecord::RecordInvalid.new(self) unless valid?

      true
    end
  end

  setup do
    @dummy = DummyRetainable.new
    DummyRetainable.database_now_value = nil
  end

  test "persistent retainable records use semantic retention column names" do
    assert_includes Client.column_names, "discard_at"
    assert_includes Client.column_names, "purge_eligible_at"
    assert_not_includes Client.column_names, "discarded_at"
    assert_not_includes Client.column_names, "purged_at"
  end

  test "accessible? returns true if discard_at is in the future" do
    @dummy.discard_at = 1.hour.from_now

    assert_predicate @dummy, :accessible?

    @dummy.discard_at = Retainable::SENTINEL

    assert_predicate @dummy, :accessible?
  end

  test "accessible? returns false if discard_at is in the past" do
    @dummy.discard_at = 1.hour.ago

    assert_not @dummy.accessible?
  end

  test "negative infinity is not an accessible retention deadline" do
    @dummy.discard_at = -Float::INFINITY

    assert_not_predicate @dummy, :accessible?
    assert_predicate @dummy, :lapsed?
  end

  test "lapsed? returns true if discard_at is in the past" do
    @dummy.discard_at = 1.hour.ago

    assert_predicate @dummy, :lapsed?
  end

  test "purgeable? returns true if purge_eligible_at is in the past" do
    @dummy.purge_eligible_at = 1.hour.ago

    assert_predicate @dummy, :purgeable?
  end

  test "negative infinity is purgeable rather than an eternal retention period" do
    @dummy.purge_eligible_at = -Float::INFINITY

    assert_predicate @dummy, :purgeable?
  end

  test "retention predicates use the supplied evaluation time" do
    evaluation_time = Time.utc(2040, 1, 1, 12)
    @dummy.discard_at = evaluation_time + 1.hour
    @dummy.purge_eligible_at = evaluation_time + 2.hours

    Time.stub(:current, Time.utc(2030, 1, 1, 12)) do
      assert_predicate @dummy, :accessible?
      assert_not @dummy.accessible?(evaluation_time + 2.hours)
      assert @dummy.lapsed?(evaluation_time + 2.hours)
      assert_not @dummy.purgeable?(evaluation_time + 1.hour)
      assert @dummy.purgeable?(evaluation_time + 2.hours)
    end
  end

  test "discard_now validates its purge deadline against the supplied evaluation time" do
    evaluation_time = Time.utc(2030, 1, 1, 12)
    @dummy.created_at = evaluation_time - 1.hour

    Time.stub(:current, Time.utc(2040, 1, 1, 12)) do
      @dummy.discard_now!(purge_after: 1.day, now: evaluation_time)
    end

    assert_equal evaluation_time, @dummy.discard_at
    assert_equal evaluation_time + 1.day, @dummy.purge_eligible_at
  end

  test "discard_now uses the model writer database clock when no time is supplied" do
    database_time = Time.utc(2040, 1, 1, 12)
    DummyRetainable.database_now_value = database_time
    @dummy.created_at = database_time - 1.hour

    @dummy.discard_now!(purge_after: 1.day)

    assert_equal database_time, @dummy.discard_at
    assert_equal database_time + 1.day, @dummy.purge_eligible_at
  end

  test "defaults use infinity sentinel" do
    assert_equal Float::INFINITY, @dummy.discard_at
    assert_equal Float::INFINITY, @dummy.purge_eligible_at
  end

  test "validates discard_at <= purge_eligible_at" do
    @dummy.discard_at = 2.hours.from_now
    @dummy.purge_eligible_at = 1.hour.from_now

    assert_not @dummy.valid?
    assert_includes @dummy.errors[:discard_at], "must be <= purge_eligible_at"
  end

  test "validates retention times not before created_at on update" do
    @dummy.created_at = 2.hours.ago
    @dummy.validation_context = :update

    @dummy.discard_at = 3.hours.ago

    assert_not @dummy.valid?
    assert_includes @dummy.errors[:discard_at], "must be >= created_at"

    @dummy.purge_eligible_at = 3.hours.ago
    @dummy.valid?

    assert_includes @dummy.errors[:purge_eligible_at], "must be >= created_at"
  end

  test "schedule_retention! raises ArgumentError if times are invalid" do
    assert_raises(ArgumentError) do
      @dummy.schedule_retention!(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.from_now)
    end
    assert_raises(ArgumentError) do
      @dummy.schedule_retention!(discard_at: 1.hour.from_now, purge_eligible_at: 1.hour.ago)
    end
    assert_raises(ArgumentError) {
      @dummy.schedule_retention!(discard_at: 2.hours.from_now, purge_eligible_at: 1.hour.from_now)
    }
  end

  test "schedule_retention! compares deadlines with the model writer database clock" do
    database_time = Time.utc(2040, 1, 1, 12)
    DummyRetainable.database_now_value = database_time

    assert_raises(ArgumentError) do
      @dummy.schedule_retention!(
        discard_at: database_time - 1.hour,
        purge_eligible_at: database_time + 1.day,
      )
    end
  end

  test "schedule_retention! updates attributes if valid" do
    future_lapses = 1.day.from_now
    future_purge = 2.days.from_now

    @dummy.schedule_retention!(discard_at: future_lapses, purge_eligible_at: future_purge)

    assert_equal future_lapses, @dummy.discard_at
    assert_equal future_purge, @dummy.purge_eligible_at
  end

  test "a discard_at later than purge_eligible_at is invalid" do
    @dummy.discard_at = 2.hours.from_now
    @dummy.purge_eligible_at = 1.hour.from_now

    assert_not @dummy.valid?
    assert_includes @dummy.errors[:discard_at], "must be <= purge_eligible_at"
  end
end
