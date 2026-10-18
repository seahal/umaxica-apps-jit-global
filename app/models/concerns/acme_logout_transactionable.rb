# typed: false
# frozen_string_literal: true

module AcmeLogoutTransactionable
  extend ActiveSupport::Concern

  ORIGIN_SURFACES = %w(sign acme base core warp edit palm tech).freeze
  LEGACY_WORKFLOW = "legacy"
  BROWSER_RP_WORKFLOW = "browser_rp"
  WORKFLOWS = [LEGACY_WORKFLOW, BROWSER_RP_WORKFLOW].freeze
  BROWSER_RP_ORIGIN_SURFACES = %w(base core warp edit palm tech).freeze
  BINDING_VERSION_LEGACY = 0
  BINDING_VERSION_BROWSER_RP = 1
  BINDING_VERSIONS = [BINDING_VERSION_LEGACY, BINDING_VERSION_BROWSER_RP].freeze
  BROWSER_RP_REALMS = %w(app com org).freeze
  BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY = :browser_rp_logout_intent_proofs
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
  STEP_AUTHORITY_REVOKED = "authority_revoked"
  STEP_AUTHORITY_CLEANUP_ISSUED = "authority_cleanup_issued"
  STEP_ORIGIN_CLEANUP_ISSUED = "origin_cleanup_issued"
  STEP_ORIGIN_RP_SESSION_REVOKED = "origin_rp_session_revoked"
  STEPS = [
    STEP_ORIGIN_CLEARED,
    STEP_ACME_CLEARED,
    STEP_SIGN_CLEARED,
    STEP_AUTHORITY_REVOKED,
    STEP_AUTHORITY_CLEANUP_ISSUED,
    STEP_ORIGIN_CLEANUP_ISSUED,
    STEP_ORIGIN_RP_SESSION_REVOKED,
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
    validate :browser_rp_binding_is_complete
  end

  class_methods do
    def step_sequence_for(origin_surface, workflow: LEGACY_WORKFLOW)
      return browser_rp_step_sequence if workflow.to_s == BROWSER_RP_WORKFLOW

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

    def browser_rp_step_sequence
      [
        STEP_AUTHORITY_REVOKED,
        STEP_AUTHORITY_CLEANUP_ISSUED,
        STEP_ORIGIN_CLEANUP_ISSUED,
        STEP_ORIGIN_RP_SESSION_REVOKED,
      ]
    end
  end

  public

  def initiated?
    status == STATUS_INITIATED
  end

  def browser_rp_workflow?
    workflow == BROWSER_RP_WORKFLOW
  end

  def browser_rp_binding_v1?
    binding_version.to_i == BINDING_VERSION_BROWSER_RP
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
    self.class.step_sequence_for(origin_surface, workflow: workflow)
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

    if browser_rp_workflow?
      return if BROWSER_RP_ORIGIN_SURFACES.include?(origin_surface) && step_sequence.include?(expected_step)
    elsif step_sequence.include?(expected_step)
      return
    end

    errors.add(:expected_step, "is not valid for the logout workflow")
  end

  def completed_steps_match_workflow
    return if workflow.blank?

    step_sequence =
      if browser_rp_workflow?
        self.class.browser_rp_step_sequence
      else
        self.class.step_sequence_for(origin_surface)
      end
    allowed_steps = step_sequence + [STEP_FINALIZED]
    invalid = completed_steps - allowed_steps
    return if invalid.empty?

    errors.add(:completed_steps, "contains steps from another logout workflow")
  end

  def browser_rp_binding_is_complete
    return unless browser_rp_binding_v1?

    errors.add(:binding_version, "is only supported for Browser RP workflow") unless browser_rp_workflow?
    errors.add(:realm, "is not a supported Browser RP realm") unless BROWSER_RP_REALMS.include?(realm.to_s)
    errors.add(:actor_ref, "must be present") if actor_ref.blank?
    errors.add(:session_ref, "must be present") if session_ref.blank?
    errors.add(:parent_session_ref, "must be present") if parent_session_ref.blank?
    errors.add(:captured_root_ref, "must be present") if captured_root_ref.blank?
    errors.add(:root_refresh_family_ref, "must be present") if root_refresh_family_ref.blank?

    generation = captured_root_generation
    if !generation.is_a?(Integer) || generation.negative?
      errors.add(:captured_root_generation, "must be a nonnegative integer")
    end

    digest_bytes = origin_intent_digest.to_s.b.bytesize
    errors.add(:origin_intent_digest, "must contain 32 bytes") unless digest_bytes == 32
  end
end
