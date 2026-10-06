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

  def mark_restricted!(now: nil)
    update_status_transition!(
      { self.class.token_status_foreign_key => self.class.token_status_model::RESTRICTED },
      now: now,
    )
  end

  def promote_to_active!(now: nil)
    update_status_transition!(
      { self.class.token_status_foreign_key => self.class.token_status_model::ACTIVE },
      now: now,
    )
  end

  public

  # Concrete token models provide step_up_authority_binding. Only explicit lifecycle changes
  # touch these rows; normal requests do not acquire additional credential or ceremony locks.
  def revoke_step_up_authority!(now: nil, except_transaction_ref: nil)
    session_model, transaction_model, ceremony_model, token_key = step_up_authority_binding
    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        decision_time = now || self.class.database_now
        update!(
          last_step_up_at: nil, last_step_up_scope: nil,
          # @deprecated `last_step_up_aal` is a historical label and never an authority input.
          last_step_up_aal: nil,
          last_step_up_method: nil, last_step_up_purpose: nil, last_step_up_audience: nil,
          last_step_up_session_public_id: nil, last_step_up_phishing_resistant: false,
          last_step_up_user_verified: nil, last_step_up_credential_ref: nil,
          last_step_up_full_reauthentication: nil, last_step_up_resource_ref: nil,
          last_step_up_tenant_ref: nil,
        )
        record = session_model.where(token_key => id).lock.first
        record&.update!(discard_at: decision_time)
        transactions = transaction_model.where(session_ref: public_id, status: %w(pending verified))
        transactions = transactions.where.not(transaction_id: except_transaction_ref) if except_transaction_ref.present?
        transactions.order(:id).lock.each do |ceremony_transaction|
          ceremony_transaction.commit_revocation!(now: decision_time)
          ceremonies = ceremony_model.where(step_up_ceremony_transaction_ref: ceremony_transaction.transaction_id)
          ceremonies.order(:id).lock.each do |ceremony|
            ceremony.revoke!(now: decision_time) unless ceremony.terminal?
          end
        end
      end
    end
  end

  def revoke!(now: nil)
    ensure_token_status_defaults!
    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        decision_time = now || self.class.database_now
        attrs = { self.class.token_status_foreign_key => self.class.token_status_model::REVOKED }
        attrs[:discard_at] = [decision_time, created_at].compact.max if has_attribute?(:discard_at)
        update_status_transition!(attrs, now: decision_time)
        revoke_step_up_authority!(now: decision_time)
      end
    end
  end

  def expired?(now = Time.current)
    return true if revoked?
    return true if token_status_id == self.class.token_status_model::EXPIRED
    return true if has_attribute?(:discard_at) && discard_at.blank?
    if respond_to?(:discard_at) && has_attribute?(:discard_at) && past_or_present_time?(discard_at, now)
      return true
    end
    return true if scheduled_revocation_due?(now)

    false
  end

  def currently_usable?(now = Time.current)
    return false if expired?(now)
    return false if has_attribute?(:rotated_at) && rotated_at.present?
    return false if has_attribute?(:discard_at) && past_or_present_time?(discard_at, now)

    true
  end

  def scheduled_revocation_due?(now = Time.current)
    has_attribute?(:discard_at) && past_or_present_time?(discard_at, now)
  end

  module ClassMethods
    def currently_usable_at(now = Time.current)
      scope = currently_valid_at(now)
      scope = scope.where(rotated_at: nil) if column_names.include?("rotated_at")

      if column_names.include?("discard_at")
        scope = scope.where(arel_table[:discard_at].gt(now))
      end
      if column_names.include?(token_status_foreign_key.to_s)
        scope = scope.where.not(token_status_foreign_key => [token_status_model::EXPIRED, token_status_model::REVOKED])
      end

      scope
    end

    def currently_valid_at(now = Time.current)
      return all unless column_names.include?("discard_at")

      where(arel_table[:discard_at].gt(now))
    end

    def expiry_column
      return :discard_at if column_names.include?("discard_at")

      raise ArgumentError, "#{name} does not have discard_at column"
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
    return true if value.respond_to?(:infinite?) && value.infinite? == -1
    return false if value.blank?
    return false if value.respond_to?(:infinite?) && value.infinite? == 1

    value <= now
  end

  def update_status_transition!(attrs, now: nil)
    attrs = attrs.dup
    now ||= self.class.database_now
    attrs[:updated_at] = now if has_attribute?(:updated_at)
    operation =
      lambda do
        assign_attributes(attrs)
        save!(touch: false)
      end
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end
end
