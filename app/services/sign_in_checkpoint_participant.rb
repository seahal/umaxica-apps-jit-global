# typed: false
# frozen_string_literal: true

class SignInCheckpointParticipant
  def initialize(cycle:, actor:, evaluators: [])
    @cycle = cycle
    @actor = actor
    @evaluators = evaluators
  end

  def evaluate
    SignInParticipantResult.new(
      participant: :checkpoint,
      stack: stack,
      next_status: "SELECTOR_PENDING",
    )
  end

  def advance_if_clear!
    cycle.with_cycle_lock do
      cycle.require_active_cycle!
      result = evaluate
      next result if result.blocking?

      cycle.advance_sign_in_to_selector!
      result
    end
  end

  private

  attr_reader :cycle, :actor, :evaluators

  def stack
    evaluators.filter_map do |evaluator|
      normalize_item(evaluator.call(cycle: cycle, actor: actor))
    end
  end

  def normalize_item(item)
    return nil if item.blank?
    return item if item.is_a?(SignInParticipantItem)

    raise ArgumentError, "checkpoint evaluator must return SignInParticipantItem"
  end
end
