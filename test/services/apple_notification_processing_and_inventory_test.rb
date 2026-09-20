# typed: false
# frozen_string_literal: true

require "test_helper"

# A notification that names no linked identity has nothing to act on, and an
# inventory asked about no actor has nothing to report. Both answer emptily
# rather than raising, because both are read on paths that must not fail when the
# subject has already been removed.
class AppleNotificationProcessingAndInventoryTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities

  test "a processor without a notification event at all is refused at construction" do
    assert_raises(ArgumentError) { ExternalAuthenticationAppleNotificationProcessor.new(event: nil) }
  end

  # The inventory is read to decide which factors may still be offered. With no
  # actor it has to report none of each rather than raise, so a signed-out caller
  # is offered nothing rather than seeing an error.
  test "an inventory for no actor reports every list empty" do
    result = AuthenticationCredentialInventory.call(nil)

    assert_nil result.actor
    assert_empty result.aal1_methods
    assert_empty result.aal2_methods
    assert_empty result.aal3_methods
    assert_empty result.contact_identifiers
    assert_empty result.phishing_resistant_methods
  end

  test "an inventory for a real actor reports that actor and a third factor list that is always empty" do
    result = AuthenticationCredentialInventory.call(clients(:one))

    assert_equal clients(:one), result.actor
    assert_empty result.aal3_methods, "no surface issues a third factor yet"
  end

  test "each principal kind is counted through the contact table its own surface owns" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)

    visitor_result = AuthenticationCredentialInventory.call(visitor)
    operator_result = AuthenticationCredentialInventory.call(operator)

    assert_equal visitor, visitor_result.actor
    assert_empty visitor_result.contact_identifiers
    assert_equal operator, operator_result.actor
    # The staff surface keeps no contact identifier of its own, so the count is
    # zero rather than read from another surface's table.
    assert_empty operator_result.contact_identifiers
  end

  # Two availability slots claiming the same hostname would leave the switch that
  # answers for it undefined, so the registry refuses to build at all.
  test "a hostname claimed by two availability slots is refused by name" do
    registry = FqdnAvailabilityRegistry.dup
    # `Module#dup` copies instance variables, so a registry whose `@index` was
    # already memoized -- anything that resolved a hostname earlier in the
    # process does that -- hands the copy a built index and `index` never runs.
    # Drop the inherited memo so the duplicate builds from the slots below.
    registry.remove_instance_variable(:@index) if registry.instance_variable_defined?(:@index)
    slot = Struct.new(:name, :hostnames)
    registry.define_singleton_method(:slots) do
      [slot.new(:first, %w(shared.example.test)), slot.new(:second, %w(shared.example.test))]
    end

    error = assert_raises(ArgumentError) { registry.slot_for("shared.example.test") }

    assert_match(/claimed by both/, error.message)
  end
end
