# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_chronicles
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
#  level_id       :bigint           default(4), not null
#  subject_id     :bigint           not null
#
# Indexes
#
#  idx_on_subject_type_subject_id_occurred_at_a29eb711dd  (subject_type,subject_id,occurred_at)
#  index_client_chronicles_on_actor_id_and_occurred_at    (actor_id,occurred_at)
#  index_client_chronicles_on_event_id                    (event_id)
#  index_client_chronicles_on_level_id                    (level_id)
#  index_client_chronicles_on_occurred_at                 (occurred_at)
#  index_client_chronicles_on_purge_eligible_at                   (purge_eligible_at)
#  index_client_chronicles_on_subject_id                  (subject_id)
#  index_user_activities_on_actor                         (actor_type,actor_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => client_chronicle_events.id)
#  fk_rails_...  (level_id => client_chronicle_levels.id)
#

require "test_helper"

class ClientChronicleTest < ActiveSupport::TestCase
  fixtures :clients, :operators, :client_chronicle_events, :client_chronicle_levels, :client_statuses

  def setup
    @user = clients(:one)
    @audit_event = ClientChronicleEvent.find(ClientChronicleEvent::LOGIN_SUCCESS)
    @level = ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::INFO)
    @audit = ClientChronicle.create!(
      user: @user,
      user_chronicle_level: @level,
      user_chronicle_event: @audit_event,
      timestamp: Time.current,
      ip_address: "192.168.1.1",
    )
  end

  test "uses bigint primary key" do
    assert_kind_of Integer, @audit.id
  end

  test "inherits from ChronicleRecord" do
    assert_operator ClientChronicle, :<, ChronicleRecord
  end

  test "ip_address can be stored" do
    assert_equal "192.168.1.1", @audit.ip_address.to_s
  end

  test "requires user" do
    audit = ClientChronicle.new(
      user_chronicle_event: @audit_event,
    )

    assert_not audit.valid?
    assert_not_empty audit.errors[:subject_id]
  end

  test "requires user_chronicle_event" do
    audit = ClientChronicle.new(
      user: @user,
    )

    # Defaults to NOTHING, so it should be valid
    assert_predicate audit, :valid?
  end

  test "validates foreign key constraint on event_id" do
    audit = ClientChronicle.new(
      user: @user,
      event_id: 9999,
      timestamp: Time.current,
    )

    # Now validation should catch it before reaching the database
    assert_not audit.valid?
    assert_not_empty audit.errors[:event_id]
    assert_includes audit.errors[:event_id], "must reference a valid user audit event"
  end

  test "belongs to polymorphic actor" do
    association = ClientChronicle.reflect_on_association(:actor)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
    assert_predicate association, :polymorphic?
  end

  test "can be created with a Client as actor" do
    actor_user = clients(:one)
    audit = ClientChronicle.create!(
      user: @user,
      user_chronicle_event: @audit_event,
      actor: actor_user,
    )

    assert_equal actor_user.id, audit.actor_id
    assert_equal "Client", audit.actor_type
    assert_equal actor_user, audit.actor
  end

  test "can be created with an Operator as actor" do
    actor_staff = operators(:one)
    audit = ClientChronicle.create!(
      user: @user,
      user_chronicle_event: @audit_event,
      actor: actor_staff,
    )

    assert_equal actor_staff.id, audit.actor_id
    assert_equal "Operator", audit.actor_type
    assert_equal actor_staff, audit.actor
  end

  test "Client and Operator can both be actors in different audits" do
    actor_user = clients(:one)
    actor_staff = operators(:one)

    # Multiple audits for the same user can have different actors
    ClientChronicle.create!(
      user: @user,
      user_chronicle_event: @audit_event,
      actor: actor_user,
    )

    ClientChronicle.create!(
      user: @user,
      user_chronicle_event: @audit_event,
      actor: actor_staff,
    )

    # Retrieve multiple audits related to the same Client
    user_actors = @user.client_chronicles.where(actor_type: "Client")
    staff_actors = @user.client_chronicles.where(actor_type: "Operator")

    assert_not_empty user_actors
    assert_not_empty staff_actors
  end

  # Additional tests for helper methods
  test "user helper method returns user" do
    assert_equal @user, @audit.user
  end

  test "user_id helper method returns user id" do
    assert_equal @user.id.to_s, @audit.user_id
  end

  test "user helpers return nil for non user subjects" do
    audit = ClientChronicle.new(subject_id: @user.id.to_s, subject_type: "Staff")

    assert_nil audit.user
    assert_nil audit.user_id
  end

  test "event validation skips blank event id" do
    audit = ClientChronicle.new(user: @user, event_id: nil)

    audit.send(:event_id_must_exist)

    assert_empty audit.errors[:event_id]
  end

  test "occurred_at alias works" do
    assert_equal @audit.timestamp, @audit.occurred_at
  end

  test "set_timestamp defaults to current time" do
    audit = ClientChronicle.new(user_chronicle_event: @audit_event)
    audit.user = @user
    audit.save!

    assert_not_nil audit.timestamp
  end

  test "actor defaults to subject user if blank" do
    audit = ClientChronicle.create!(
      user: @user,
      user_chronicle_event: @audit_event,
      actor: nil,
    )

    assert_equal @user.id, audit.actor_id
    assert_equal "Client", audit.actor_type
  end
end
