# typed: false
# frozen_string_literal: true

class SignInGuardrailParticipant
  GENERIC_MESSAGE = I18n.t("errors.messages.not_authorized")

  DEFAULT_EVALUATORS = [
    :actor_login_allowed_item,
  ].freeze

  def initialize(cycle:, actor:, evaluators: DEFAULT_EVALUATORS)
    @cycle = cycle
    @actor = actor
    @evaluators = evaluators
  end

  def evaluate
    SignInParticipantResult.new(
      participant: :guardrail,
      stack: stack,
      next_status: "CHECKPOINT_PENDING",
      message: GENERIC_MESSAGE,
    )
  end

  def advance_if_clear!
    cycle.class.transaction do
      cycle.lock!
      result = evaluate
      return result if result.blocking?

      cycle.advance_sign_in_to_checkpoint!
      result
    end
  end

  private

  attr_reader :cycle, :actor, :evaluators

  def stack
    evaluators.filter_map do |evaluator|
      item = evaluator.respond_to?(:call) ? evaluator.call(cycle: cycle, actor: actor) : send(evaluator)
      normalize_item(item)
    end
  end

  def actor_login_allowed_item
    return nil unless actor.respond_to?(:login_allowed?)
    return nil if actor.login_allowed?

    blocking_item(:actor_login_not_allowed)
  end

  def blocking_item(key)
    SignInParticipantItem.new(key: key, blocking: true, cleared: false, message: GENERIC_MESSAGE)
  end

  def normalize_item(item)
    return nil if item.blank?
    return item if item.is_a?(SignInParticipantItem)

    raise ArgumentError, "guardrail evaluator must return SignInParticipantItem"
  end
end
