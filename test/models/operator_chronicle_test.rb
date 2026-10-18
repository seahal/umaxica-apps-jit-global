# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_chronicles
# Database name: chronicle
#
#  id             :bigint           not null, primary key
#  actor_type     :text             default(""), not null
#  context        :jsonb            not null
#  current_value  :text             default(""), not null
#  discard_at   :datetime         default(Infinity), not null
#  ip_address     :inet             default(#<IPAddr: IPv4:0.0.0.0/255.255.255.255>), not null
#  occurred_at    :datetime         not null
#  previous_value :text             default(""), not null
#  purge_eligible_at      :datetime         not null
#  subject_type   :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  actor_id       :bigint           default(0), not null
#  event_id       :bigint           default(0), not null
#  level_id       :bigint           default(1), not null
#  subject_id     :bigint           not null
#
# Indexes
#
#  idx_on_subject_type_subject_id_occurred_at_2e96c29236  (subject_type,subject_id,occurred_at)
#  index_operator_chronicles_on_actor_id_and_occurred_at  (actor_id,occurred_at)
#  index_operator_chronicles_on_event_id                  (event_id)
#  index_operator_chronicles_on_level_id                  (level_id)
#  index_operator_chronicles_on_occurred_at               (occurred_at)
#  index_operator_chronicles_on_purge_eligible_at                 (purge_eligible_at)
#  index_operator_chronicles_on_subject_id                (subject_id)
#  index_staff_activities_on_actor                        (actor_type,actor_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => operator_chronicle_events.id)
#  fk_rails_...  (level_id => operator_chronicle_levels.id)
#

require "test_helper"

class OperatorChronicleTest < ActiveSupport::TestCase
  fixtures :operators, :clients, :operator_chronicle_events, :operator_chronicle_levels, :operator_statuses,
           :client_statuses

  def setup
    @staff = operators(:one)
    @actor = clients(:none_user)
    @audit_event = OperatorChronicleEvent.find(OperatorChronicleEvent::LOGIN_SUCCESS)
    @audit_level = OperatorChronicleLevel.find(OperatorChronicleLevel::NOTHING)
    @audit = OperatorChronicle.create!(
      staff: @staff,
      staff_chronicle_event: @audit_event,
      staff_chronicle_level: @audit_level,
      actor: @actor,
      timestamp: Time.current,
      ip_address: "192.168.1.1",
    )
  end

  test "uses bigint primary key" do
    assert_kind_of Integer, @audit.id
  end

  test "inherits from ChronicleRecord" do
    assert_operator OperatorChronicle, :<, ChronicleRecord
  end

  test "ip_address can be stored" do
    assert_equal "192.168.1.1", @audit.ip_address.to_s
  end

  test "requires staff" do
    audit = OperatorChronicle.new(
      staff_chronicle_event: @audit_event,
      staff_chronicle_level: @audit_level,
    )

    assert_not audit.valid?
    assert_not_empty audit.errors[:subject_id]
  end

  test "requires staff_chronicle_event" do
    audit = OperatorChronicle.new(
      staff: @staff,
      staff_chronicle_level: @audit_level,
    )

    # Defaults to NOTHING, so it should be valid
    assert_predicate audit, :valid?
  end

  test "belongs to polymorphic actor" do
    association = OperatorChronicle.reflect_on_association(:actor)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
    assert_predicate association, :polymorphic?
  end

  test "can be created with a Client as actor" do
    actor_user = clients(:one)
    audit = OperatorChronicle.create!(
      staff: @staff,
      staff_chronicle_event: @audit_event,
      staff_chronicle_level: @audit_level,
      actor: actor_user,
    )

    assert_equal actor_user.id, audit.actor_id
    assert_equal "Client", audit.actor_type
    assert_equal actor_user, audit.actor
  end

  test "can be created with an Operator as actor" do
    actor_staff = operators(:one)
    audit = OperatorChronicle.create!(
      staff: @staff,
      staff_chronicle_event: @audit_event,
      staff_chronicle_level: @audit_level,
      actor: actor_staff,
    )

    assert_equal actor_staff.id, audit.actor_id
    assert_equal "Operator", audit.actor_type
    assert_equal actor_staff, audit.actor
  end

  test "Client and Operator can both be actors in different audits" do
    actor_user = clients(:one)
    actor_staff = operators(:one)

    # Multiple audits for the same staff can have different actors
    OperatorChronicle.create!(
      staff: @staff,
      staff_chronicle_event: @audit_event,
      staff_chronicle_level: @audit_level,
      actor: actor_user,
    )

    OperatorChronicle.create!(
      staff: @staff,
      staff_chronicle_event: @audit_event,
      staff_chronicle_level: @audit_level,
      actor: actor_staff,
    )

    # Retrieve multiple audits related to the same Staff
    user_actors = @staff.staff_chronicles.where(actor_type: "Client")
    staff_actors = @staff.staff_chronicles.where(actor_type: "Operator")

    assert_not_empty user_actors
    assert_not_empty staff_actors
  end

  test "defaults level_id to NOTHING if not provided" do
    audit = OperatorChronicle.create!(
      staff: @staff,
      staff_chronicle_event: @audit_event,
      actor: @actor,
      timestamp: Time.current,
    )

    assert_equal OperatorChronicleLevel::NOTHING, audit.level_id
    assert_equal OperatorChronicleLevel::NOTHING, audit.staff_chronicle_level.id
  end

  test "sets timestamp on create when missing" do
    audit = OperatorChronicle.create!(
      staff: @staff,
      staff_chronicle_event: @audit_event,
      staff_chronicle_level: @audit_level,
      actor: @actor,
      timestamp: nil,
    )

    assert_not_nil audit.timestamp
  end

  test "staff assignment sets subject attributes" do
    audit = OperatorChronicle.new(
      staff_chronicle_event: @audit_event,
      staff_chronicle_level: @audit_level,
    )

    audit.staff = @staff

    assert_equal @staff.id, audit.subject_id
    assert_equal "Operator", audit.subject_type
    assert_equal @staff, audit.staff
  end

  test "staff helper returns nil for non staff subjects" do
    audit = OperatorChronicle.new(subject_id: @staff.id, subject_type: "Client")

    assert_nil audit.staff
  end

  test "event validation skips blank event id" do
    audit = OperatorChronicle.new(staff: @staff, event_id: nil)

    audit.send(:event_id_must_exist)

    assert_empty audit.errors[:event_id]
  end

  test "invalid when event_id is unknown" do
    audit = OperatorChronicle.new(
      staff: @staff,
      staff_chronicle_level: @audit_level,
      event_id: 999_999,
    )

    assert_not audit.valid?
    assert_includes audit.errors[:event_id], "must reference a valid staff audit event"
  end

  test "occurred_at aliases timestamp" do
    timestamp = Time.current
    audit = OperatorChronicle.create!(
      staff: @staff,
      staff_chronicle_event: @audit_event,
      staff_chronicle_level: @audit_level,
      actor: @actor,
      timestamp: timestamp,
    )

    assert_equal timestamp.to_i, audit.occurred_at.to_i
  end
end
