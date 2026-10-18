# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch33PreciseArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "SignInSelectorParticipant auto_commit requires single candidate" do
    cycle = Object.new
    cycle.define_singleton_method(:class) { ClientSignInFlow }
    cycle.define_singleton_method(:lock!) { true }
    cycle.define_singleton_method(:sign_in_selector_pending?) { true }
    cycle.define_singleton_method(:expired?) { false }
    cycle.define_singleton_method(:principal_id) { 1 }
    cycle.define_singleton_method(:transaction) { |&block| block.call }

    resolver = Object.new
    resolver.define_singleton_method(:candidates) { [] }

    actor = Client.new
    actor.define_singleton_method(:id) { 1 }
    participant = SignInSelectorParticipant.new(cycle: cycle, actor: actor, resolver: resolver)
    participant.define_singleton_method(:ensure_selector_cycle!) { true }
    participant.define_singleton_method(:resolved_actor) { actor }

    # Stub transaction on the cycle class path used inside auto_commit_single!
    ClientSignInFlow.stub(:transaction, ->(&b) { b.call }) do
      cycle.define_singleton_method(:lock!) { true }
      assert_raises(SignInSelectorParticipant::InvalidCycle) { participant.auto_commit_single! }
    end
  end

  test "Publishing create entry operation easy guard" do
    error = assert_raises(ArgumentError) { Publishing::CreateEntryOperation.new }

    assert_match(/missing keyword/, error.message)
  end
end
