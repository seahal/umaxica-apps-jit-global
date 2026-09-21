# typed: false
# frozen_string_literal: true

require "test_helper"

class FlowSignUpTest < ActiveSupport::TestCase
  class FlowSignUpTestRecord < ApplicationRecord
    self.table_name = "flow_sign_up_test_records"

    include Retainable
    include FlowSignUp

    STATUSES = {
      "STARTED" => 10,
      "CONTACT_PENDING" => 20,
      "CREDENTIAL_PENDING" => 30,
      "CHECKPOINT_PENDING" => 40,
      "COMPLETED" => 100,
      "FAILED" => 110,
      "EXPIRED" => 120,
      "CANCELLED" => 130,
    }.freeze
    STATUS_NAMES = STATUSES.invert.freeze
    STATUS_IDS = STATUSES.values.freeze
    STEPS = %w(start contact credential checkpoint completed failed expired cancelled).freeze

    def self.status_id_for(name)
      STATUSES.fetch(name.to_s)
    end

    def self.status_ids_for(*names)
      names.map { |name| status_id_for(name) }
    end

    delegate :status_id_for, to: :class
    delegate :status_ids_for, to: :class
  end

  class FlowSignUpWithoutCancelledTestRecord < FlowSignUpTestRecord
    STATUSES = FlowSignUpTestRecord::STATUSES.except("CANCELLED").freeze
    STATUS_NAMES = STATUSES.invert.freeze
    STATUS_IDS = STATUSES.values.freeze

    def self.status_id_for(name)
      STATUSES.fetch(name.to_s)
    end
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:flow_sign_up_test_records, force: true) do |t|
      t.integer(:status_id, null: false)
      t.string(:step)
      t.datetime(:discard_at, null: false)
      t.datetime(:purge_eligible_at, null: false)
      t.datetime(:expires_at)
      t.datetime(:completed_at)
      t.timestamps
    end
    FlowSignUpTestRecord.reset_column_information
    FlowSignUpWithoutCancelledTestRecord.reset_column_information
  end

  teardown do
    @connection.drop_table(:flow_sign_up_test_records, if_exists: true)
  end

  test "predicates reflect the current sign-up status" do
    record = create_record(:started)

    assert_predicate record, :sign_up_started?
    assert_not record.sign_up_contact_pending?
    assert_not record.sign_up_credential_pending?
    assert_not record.sign_up_checkpoint_pending?
    assert_not record.sign_up_completed?
    assert_predicate record, :sign_up_in_progress?
    assert_predicate record, :sign_up_cancelable?
    assert_not record.sign_up_terminal?
  end

  test "class methods resolve status ids and tolerate unknown status names" do
    assert_equal [10], FlowSignUpTestRecord.sign_up_status_ids_for("STARTED", "UNKNOWN")
    assert_includes FlowSignUpTestRecord.sign_up_in_progress_status_ids, 10
    assert_includes FlowSignUpTestRecord.sign_up_cancelable_status_ids, 10
    assert_equal [100, 110, 120, 130], FlowSignUpTestRecord.sign_up_terminal_status_ids
  end

  test "sign_up_cancelled? returns false when the cancelled status is undefined" do
    record = create_record(:started, record_class: FlowSignUpWithoutCancelledTestRecord)

    assert_not record.sign_up_cancelled?
  end

  test "advances through the sign-up lifecycle and completes" do
    record = create_record(:started)

    record.advance_sign_up_to_contact!

    assert_equal 20, record.status_id
    assert_equal "contact", record.step

    record.advance_sign_up_to_credential!

    assert_equal 30, record.status_id

    record.advance_sign_up_to_checkpoint!

    assert_equal 40, record.status_id

    record.complete_sign_up!
    record.reload

    assert_equal 100, record.status_id
    assert_equal "completed", record.step
    assert_predicate record, :sign_up_completed?
    assert_not record.sign_up_in_progress?
    assert_not record.sign_up_cancelable?
    assert_predicate record, :sign_up_terminal?
    assert_predicate record.completed_at, :present?
  end

  test "discard_sign_up sets retention timestamps" do
    record = create_record(:started)

    record.discard_sign_up!(now: record.created_at)

    assert_equal record.created_at, record.discard_at
  end

  private

  def create_record(status_name, record_class: FlowSignUpTestRecord)
    status_id = record_class.status_id_for(status_name.to_s.upcase)
    now = Time.current

    record_class.create!(
      status_id: status_id,
      step: "start",
      discard_at: now + 1.day,
      purge_eligible_at: now + 2.days,
      expires_at: now + 1.hour,
    )
  end
end
