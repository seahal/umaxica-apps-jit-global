# typed: false
# frozen_string_literal: true

module SignUpFlowTicket
  extend ActiveSupport::Concern

  CONTACT_TYPES = %w(email telephone social_identity).freeze
  # Symbolic cleanup states. Each surface's reference table (e.g.
  # ClientSignUpFlowCleanupStatus) defines the actual integer IDs. Access via
  # `flow.cleanup_status_id_for(:pending)` etc.
  CLEANUP_STATE_NAMES = %i(idle pending completed failed).freeze
  SECRET_REQUIREMENT_KEY_PATTERNS = [
    /otp/i,
    /pass_?code/i,
    /secret_credential/i,
    /token/i,
    /cookie/i,
    /authorization/i,
    /challenge/i,
  ].freeze

  included do
    before_validation :normalize_completed_requirements
    before_validation :default_cleanup_status

    validates :entry_method, presence: true, inclusion: { in: ->(record) { record.class::ENTRY_METHODS } }
    validates :pending_contact_type, inclusion: { in: CONTACT_TYPES }, allow_nil: true
    validates :completed_requirements, exclusion: { in: [nil] }
    validate :completed_requirements_is_object
    validate :return_to_is_safe_internal_path
    validate :completed_requirements_exclude_secret_credential_material
  end

  class_methods do
    def cleanup_status_class
      nil
    end

    def cleanup_status_id_for(state)
      klass = cleanup_status_class
      raise NotImplementedError,
            "#{name} must declare cleanup_status_class returning a ReferenceRecord " \
            "(e.g. ClientSignUpFlowCleanupStatus)" unless klass

      klass.const_get(state.to_s.upcase)
    end

    def social_entry_methods
      defined?(self::SOCIAL_ENTRY_METHODS) ? self::SOCIAL_ENTRY_METHODS : []
    end
  end

  def social_entry_method?
    self.class.social_entry_methods.include?(entry_method)
  end

  def requirement_cleared?(requirement)
    requirement_state = completed_requirements.fetch(requirement.to_s, {})

    requirement_state.is_a?(Hash) && requirement_state["cleared"] == true
  end

  def checkpoint_version
    return self[:checkpoint_version] if has_attribute?(:checkpoint_version)

    0
  end

  delegate :cleanup_status_id_for, to: :class

  def cleanup_idle?
    has_attribute?(:cleanup_status_id) && cleanup_status_id == cleanup_status_id_for(:idle)
  end

  def cleanup_pending?
    has_attribute?(:cleanup_status_id) && cleanup_status_id == cleanup_status_id_for(:pending)
  end

  def cleanup_completed?
    has_attribute?(:cleanup_status_id) && cleanup_status_id == cleanup_status_id_for(:completed)
  end

  def cleanup_failed?
    has_attribute?(:cleanup_status_id) && cleanup_status_id == cleanup_status_id_for(:failed)
  end

  def complete_sign_up!
    transition_sign_up_to!("COMPLETED")
  end

  private

  def normalize_completed_requirements
    self.completed_requirements = {} if completed_requirements.blank?
  end

  def default_cleanup_status
    return unless has_attribute?(:cleanup_status_id)

    return if cleanup_status_id.present?

    self.cleanup_status_id = cleanup_status_id_for(:idle)
  end

  def return_to_is_safe_internal_path
    return if return_to.blank?
    return if safe_internal_return_to?(return_to)

    errors.add(:return_to, "must be a safe internal path")
  end

  # Top-level keys are exempt because they are requirement names chosen by
  # SignUpRequirementRegistry, and two of them ("otp", "passcode") match the
  # patterns by design. Everything nested under them is payload written by a
  # controller, which is where secret material could realistically leak in, so
  # that is what gets inspected. See the `social_signup` evidence blob in
  # Auth::App::Omniauth::OmniauthCallbacksController for a non-requirement key
  # that also relies on this rule.
  def completed_requirements_exclude_secret_credential_material
    return unless completed_requirements.is_a?(Hash)

    flattened_keys = flatten_requirement_keys(completed_requirements, include_current_level: false)
    return if flattened_keys.none? { |key| secret_credential_requirement_key?(key) }

    errors.add(:completed_requirements, "must not contain secret_credential material")
  end

  def completed_requirements_is_object
    return if completed_requirements.is_a?(Hash)

    errors.add(:completed_requirements, "must be an object")
  end

  def flatten_requirement_keys(value, include_current_level: true)
    case value
    when Hash
      value.flat_map do |key, nested|
        nested_keys = flatten_requirement_keys(nested)
        include_current_level ? [key.to_s] + nested_keys : nested_keys
      end
    when Array
      value.flat_map { |nested| flatten_requirement_keys(nested) }
    else
      []
    end
  end

  def safe_internal_return_to?(value)
    uri = URI.parse(value.to_s)
    return false if uri.scheme.present? || uri.host.present?

    path = uri.path.to_s
    path.start_with?("/") && !path.start_with?("//")
  rescue URI::InvalidURIError
    false
  end

  def secret_credential_requirement_key?(key)
    SECRET_REQUIREMENT_KEY_PATTERNS.any? { |pattern| pattern.match?(key) }
  end
end
