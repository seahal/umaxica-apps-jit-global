# typed: false
# frozen_string_literal: true

module TokenStatusManagement
  extend ActiveSupport::Concern

  RESTRICTED_TTL = 15.minutes

  STATUS_ACTIVE = 1
  STATUS_EXPIRED = 102
  STATUS_RESTRICTED = 103
  STATUS_REVOKED = 104

  VALID_STATUSES = [STATUS_ACTIVE, STATUS_EXPIRED, STATUS_RESTRICTED, STATUS_REVOKED].freeze

  included do
    scope :session_inventory, ->(now = Time.current) { currently_usable_at(now) }
    scope :active_status,
          ->(now = Time.current) do
            currently_usable_at(now).where(token_status_foreign_key => token_status_model::ACTIVE)
          end
    scope :restricted_status,
          ->(now = Time.current) do
            currently_usable_at(now).where(token_status_foreign_key => token_status_model::RESTRICTED)
          end
    scope :not_revoked, ->(now = Time.current) { currently_usable_at(now) }
  end

  def restricted?
    token_status_id == self.class.token_status_model::RESTRICTED
  end

  # Which sign-in ceremony established this session. Emergency Access is an org
  # concept, so `authentication_context` exists on operator_tokens only; a
  # surface with no Emergency ceremony has no way to produce a non-Normal
  # session, so the absent column states Normal rather than guessing at one.
  #
  # Deliberately not `restricted?`: that marks a session-limit remediation
  # state, and the two axes are independent.
  def authentication_context_value
    return AuthenticationContextValue.normal unless has_attribute?(:authentication_context)

    AuthenticationContextValue.from_claim(authentication_context)
  end

  def emergency_authentication_context?
    authentication_context_value.emergency?
  end

  def revoked?
    token_status_id == self.class.token_status_model::REVOKED
  end

  def active_status?
    token_status_id == self.class.token_status_model::ACTIVE && currently_usable?
  end

  def mark_restricted!
    update_status_transition!(self.class.token_status_foreign_key => self.class.token_status_model::RESTRICTED)
  end

  def promote_to_active!
    update_status_transition!(self.class.token_status_foreign_key => self.class.token_status_model::ACTIVE)
  end

  def revoke!
    now = Time.current
    ensure_token_status_defaults!
    attrs = { self.class.token_status_foreign_key => self.class.token_status_model::REVOKED }
    if has_attribute?(:discarded_at)
      attrs[:discarded_at] = [now, created_at].compact.max
    end
    update_status_transition!(attrs)
  end

  def expired?
    return true if revoked?
    return true if token_status_id == self.class.token_status_model::EXPIRED
    return true if respond_to?(:discarded_at) && has_attribute?(:discarded_at) && past_or_present_time?(discarded_at)
    return true if scheduled_revocation_due?

    false
  end

  def currently_usable?(now = Time.current)
    return false if expired?
    return false if has_attribute?(:rotated_at) && rotated_at.present?
    return false if has_attribute?(:discarded_at) && past_or_present_time?(discarded_at, now)

    true
  end

  def scheduled_revocation_due?(now = Time.current)
    has_attribute?(:discarded_at) && past_or_present_time?(discarded_at, now)
  end

  module ClassMethods
    def currently_usable_at(now = Time.current)
      scope = currently_valid_at(now)
      scope = scope.where(rotated_at: nil) if column_names.include?("rotated_at")

      if column_names.include?("discarded_at")
        scope = scope.where(arel_table[:discarded_at].gt(now))
      end
      if column_names.include?(token_status_foreign_key.to_s)
        scope = scope.where.not(token_status_foreign_key => [token_status_model::EXPIRED, token_status_model::REVOKED])
      end

      scope
    end

    def currently_valid_at(now = Time.current)
      return all unless column_names.include?("discarded_at")

      where(arel_table[:discarded_at].gt(now))
    end

    def expiry_column
      return :discarded_at if column_names.include?("discarded_at")

      raise ArgumentError, "#{name} does not have discarded_at column"
    end

    def token_status_foreign_key
      column_names.find { |column_name| column_name.end_with?("_token_status_id") }&.to_sym ||
        raise(ArgumentError, "#{name} does not have token status foreign key")
    end

    def token_status_model
      case name
      when "OperatorToken" then OperatorTokenStatus
      when "ClientToken" then ClientTokenStatus
      when "VisitorToken" then VisitorTokenStatus
      else
        raise ArgumentError, "#{name} does not have token status model"
      end
    end
  end

  private

  def token_status_id
    public_send(self.class.token_status_foreign_key)
  end

  def ensure_token_status_defaults!
    status_model = self.class.token_status_model
    return unless status_model.respond_to?(:ensure_defaults!)

    operation = -> { status_model.ensure_defaults! }
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def past_or_present_time?(value, now = Time.current)
    return false if value.blank?
    return false if value.respond_to?(:infinite?) && value.infinite?

    value <= now
  end

  def update_status_transition!(attrs)
    attrs = attrs.dup
    attrs[:updated_at] = Time.current if has_attribute?(:updated_at)
    operation = -> { update!(attrs) }
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end
end
