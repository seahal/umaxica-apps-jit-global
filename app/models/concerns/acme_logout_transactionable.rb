# typed: false
# frozen_string_literal: true

module AcmeLogoutTransactionable
  extend ActiveSupport::Concern

  ORIGIN_SURFACES = %w(sign acme base core warp edit palm tech).freeze
  LEGACY_WORKFLOW = "legacy"
  WORKFLOWS = [LEGACY_WORKFLOW].freeze
  BINDING_VERSION_LEGACY = 0
  BINDING_VERSIONS = [BINDING_VERSION_LEGACY].freeze
  STATUS_INITIATED = "initiated"
  STATUS_IN_PROGRESS = "in_progress"
  STATUS_FINALIZED = "finalized"
  STATUS_FAILED = "failed"
  STATUS_EXPIRED = "expired"
  STATUSES = [STATUS_INITIATED, STATUS_IN_PROGRESS, STATUS_FINALIZED, STATUS_FAILED, STATUS_EXPIRED].freeze

  STEP_ORIGIN_CLEARED = "origin_cleared"
  STEP_ACME_CLEARED = "acme_cleared"
  STEP_SIGN_CLEARED = "sign_cleared"
  STEP_FINALIZED = "finalized"
  STEPS = [
    STEP_ORIGIN_CLEARED,
    STEP_ACME_CLEARED,
    STEP_SIGN_CLEARED,
    STEP_FINALIZED,
  ].freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include ::PublicId

    attribute :binding_version, default: BINDING_VERSION_LEGACY

    validates :origin_surface, inclusion: { in: ORIGIN_SURFACES }
    validates :workflow, inclusion: { in: WORKFLOWS }
    validates :initiating_client_id, :completion_url, :status, :expected_step, :expires_at, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :expected_step, inclusion: { in: STEPS }
    validates :binding_version, numericality: { only_integer: true }, inclusion: { in: BINDING_VERSIONS }
    validates :public_id, uniqueness: true
    validate :completed_steps_are_valid
    validate :completed_steps_match_workflow
    validate :expected_step_matches_workflow
  end

  class_methods do
    def step_sequence_for(origin_surface)
      case origin_surface.to_s
      when "sign"
        [STEP_ORIGIN_CLEARED, STEP_ACME_CLEARED]
      when "acme", "base"
        [STEP_ORIGIN_CLEARED, STEP_SIGN_CLEARED]
      when "core", "warp", "palm"
        [STEP_ORIGIN_CLEARED, STEP_ACME_CLEARED, STEP_SIGN_CLEARED]
      else
        raise ArgumentError, "unsupported logout origin surface: #{origin_surface.inspect}"
      end
    end
  end

  public

  def initiated?
    status == STATUS_INITIATED
  end

  def legacy_workflow?
    workflow == LEGACY_WORKFLOW
  end

  def in_progress?
    status == STATUS_IN_PROGRESS
  end

  def finalized?
    status == STATUS_FINALIZED
  end

  def failed?
    status == STATUS_FAILED
  end

  def expired?(now: Time.current)
    expires_at.present? && expires_at <= now
  end

  def step_sequence
    self.class.step_sequence_for(origin_surface)
  end

  def completed_steps
    Array(read_attribute(:completed_steps)).map(&:to_s)
  end

  def expected_finalization?
    expected_step == STEP_FINALIZED
  end

  def advance_step!(step, now: Time.current)
    normalized_step = normalize_step(step)
    return self if finalized? || failed?
    return self if completed_steps.include?(normalized_step)
    raise ArgumentError, "logout transaction expired" if expired?(now: now)
    raise ArgumentError, "invalid logout step" unless normalized_step == expected_step

    transaction do
      lock!
      return self if finalized? || failed?
      return self if completed_steps.include?(normalized_step)
      raise ArgumentError, "logout transaction expired" if expired?(now: now)
      raise ArgumentError, "invalid logout step" unless normalized_step == expected_step

      update!(
        completed_steps: completed_steps + [normalized_step],
        expected_step: next_expected_step_for(normalized_step),
        status: STATUS_IN_PROGRESS,
      )
    end
  end

  def finalize!(now: Time.current)
    return self if finalized?
    raise ArgumentError, "logout transaction expired" if expired?(now: now)
    raise ArgumentError, "logout transaction is not ready to finalize" unless expected_finalization?

    transaction do
      lock!
      return self if finalized?
      raise ArgumentError, "logout transaction expired" if expired?(now: now)
      raise ArgumentError, "logout transaction is not ready to finalize" unless expected_finalization?

      update!(
        completed_steps: completed_steps + [STEP_FINALIZED],
        expected_step: STEP_FINALIZED,
        status: STATUS_FINALIZED,
        finalized_at: now,
      )
    end
  end

  def fail!(now: Time.current)
    return self if failed? || finalized?

    update!(
      status: STATUS_FAILED,
      failed_at: now,
    )
  end

  private

  def normalize_step(step)
    step.to_s
  end

  def next_expected_step_for(step)
    sequence = step_sequence
    next_step = sequence[sequence.index(step) + 1]
    next_step || STEP_FINALIZED
  end

  def completed_steps_are_valid
    invalid = completed_steps - STEPS
    errors.add(:completed_steps, "contains invalid logout steps") if invalid.present?
  end

  def expected_step_matches_workflow
    return if origin_surface.blank? || expected_step.blank?
    return if expected_step == STEP_FINALIZED
    return if step_sequence.include?(expected_step)

    errors.add(:expected_step, "is not valid for the logout workflow")
  end

  def completed_steps_match_workflow
    return if workflow.blank?

    allowed_steps = self.class.step_sequence_for(origin_surface) + [STEP_FINALIZED]
    invalid = completed_steps - allowed_steps
    return if invalid.empty?

    errors.add(:completed_steps, "contains steps from another logout workflow")
  end
end
