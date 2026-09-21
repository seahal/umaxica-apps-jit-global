# typed: false
# frozen_string_literal: true

module SignFlow
  extend ActiveSupport::Concern

  included do
    include ::PublicId
    include ::Retainable

    self.belongs_to_required_by_default = false

    attribute :issued_at, :datetime, default: -> { Time.current }
    attribute :expires_at, :datetime, default: -> { default_ttl.from_now }

    before_validation :ensure_sign_flow_status_defaults
    before_validation :assign_default_status_id
    before_validation :sync_legacy_state_from_status

    validates :status_id, presence: true, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
    validates :step, presence: true, inclusion: { in: ->(record) { record.class::STEPS } }
    validates :state, presence: true
    validates :nonce_digest, presence: true
    validates :issued_at, :expires_at, presence: true
    validate :legacy_state_matches_status
    validate :step_matches_status
    validate :expires_after_issued_at
    validate :completed_state_has_completed_at

    scope :recent_first, -> { order(created_at: :desc) }
    scope :current,
          -> do
            where(arel_table[:discard_at].gt(Time.current))
              .where(arel_table[:expires_at].gt(Time.current))
          end
  end

  class_methods do
    def digest_nonce(nonce)
      OpenSSL::Digest::SHA256.hexdigest(nonce.to_s)
    end

    def default_ttl
      15.minutes
    end

    def status_id_for(status_name)
      self::STATUSES.fetch(status_name.to_s)
    end

    def status_name_for(status_id)
      self::STATUS_NAMES.fetch(status_id)
    end

    def status_ids_for(*status_names)
      status_names.map { |status_name| status_id_for(status_name) }
    end

    def completed_status_id
      status_id_for("COMPLETED")
    end
  end

  def default_expires_at
    self.class.default_ttl.from_now
  end

  # True only when the auth-flow TTL has lapsed. Distinct from `lapsed?`
  # (logical deletion) which Retainable owns; the two used to be merged here
  # but conflating them made callers reject events on rows that were merely
  # discarded for audit hold. State-machine code that wants the union should
  # check `expired? || lapsed?` explicitly.
  def expired?(now = Time.current)
    expires_at.present? && expires_at <= now
  end

  def completed?
    status_id == self.class.completed_status_id
  end

  def nonce_matches?(nonce)
    return false if nonce.blank? || nonce_digest.blank?

    ActiveSupport::SecurityUtils.secure_compare(nonce_digest, self.class.digest_nonce(nonce))
  end

  delegate :status_id_for, to: :class

  delegate :status_name_for, to: :class

  def status_ids_for(*status_names)
    self.class.status_ids_for(*status_names)
  end

  def can_transition_to?(next_status)
    next_status_id = normalize_status_id(next_status)

    self.class::TRANSITIONS.fetch(status_id, []).include?(next_status_id)
  end

  # Row-locked transition. Reading `status_id` and writing the new one must be
  # atomic -- otherwise two concurrent callers can both observe A and race-write
  # the same outbound edge, producing inconsistent state and lost updates on
  # sibling columns. `with_cycle_lock` (FlowBase) wraps in a transaction so
  # the SELECT FOR UPDATE actually holds.
  def transition_to!(next_status, step: nil, now: Time.current)
    with_cycle_lock { perform_transition!(next_status, step: step, now: now) }
  end

  def perform_transition!(next_status, step:, now:)
    # `with_cycle_lock` issues `lock!` which is itself a `reload(lock: true)`,
    # so the read of `status_id` here is already against the freshly-locked row.
    next_status_id = normalize_status_id(next_status)
    unless can_transition_to?(next_status_id)
      raise ArgumentError, "invalid transition from #{status_id.inspect} to #{next_status_id.inspect}"
    end

    attrs = { status_id: next_status_id }
    next_step = canonical_step_for_status(next_status_id) || step
    attrs[:step] = next_step if next_step.present?
    attrs[:state] = self.class::STATUS_NAMES[next_status_id] if has_attribute?(:state)
    attrs[:completed_at] = now if next_status_id == self.class.completed_status_id
    update!(attrs)
  end

  def discard!(now: Time.current)
    update!(discard_at: now)
  end

  private

  def normalize_status_id(status)
    return status if status.is_a?(Integer)

    self.class.status_id_for(status)
  end

  def canonical_step_for_status(status_id)
    return unless self.class.const_defined?(:STEP_BY_STATUS_ID, false)

    self.class::STEP_BY_STATUS_ID[status_id]
  end

  def ensure_sign_flow_status_defaults
    self.class::STATUS_MODEL.ensure_defaults!
  end

  def assign_default_status_id
    self.status_id ||= self.class::STATUS_IDS.first
  end

  def sync_legacy_state_from_status
    return unless has_attribute?(:state)
    return if status_id.blank? || state.present?

    self.state = self.class::STATUS_NAMES[status_id]
  end

  def legacy_state_matches_status
    return unless has_attribute?(:state) && status_id.present?

    expected_state = self.class::STATUS_NAMES[status_id]
    errors.add(:state, "must match status_id") if expected_state.present? && state != expected_state
  end

  def step_matches_status
    return unless self.class.const_defined?(:STEP_BY_STATUS_ID, false)
    return if status_id.blank? || step.blank?

    expected_step = self.class::STEP_BY_STATUS_ID[status_id]
    errors.add(:step, "must match status_id") if expected_step.present? && step != expected_step
  end

  def expires_after_issued_at
    return if issued_at.blank? || expires_at.blank?
    return if issued_at < expires_at

    errors.add(:expires_at, "must be after issued_at")
  end

  def completed_state_has_completed_at
    return unless completed?

    errors.add(:completed_at, "must be present for completed cycles") if completed_at.blank?
  end
end
