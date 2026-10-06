# typed: false
# frozen_string_literal: true

require "digest"

# Durable browser binding for a Base-to-Auth admission. This row is a capability
# record only after the Base browser nonce and the Auth ceremony session have
# both been validated; entry_ref and confirmation_ref are lookup identifiers,
# never proof.
module AuthAdmissionBinding
  extend ActiveSupport::Concern

  PARENT_PURPOSES = {
    sign_in_flow: %w(local_sign_in local_sign_up),
    authorization_transaction: %w(authentication_handoff invitation_handoff),
    step_up_ceremony_transaction: %w(
      step_up_handoff reauthentication_handoff bootstrap_handoff
      credential_registration_handoff credential_change_handoff
    ),
  }.freeze
  BASE_TOKEN_PURPOSES = PARENT_PURPOSES.fetch(:step_up_ceremony_transaction).freeze
  IMMUTABLE_FACT_COLUMNS = %w(
    entry_ref purpose sign_in_flow_id authorization_transaction_id step_up_ceremony_transaction_id
    base_token_id base_browser_digest expires_at auth_ceremony_session_id confirmation_ref
    base_confirmed_at redeemed_at admitted_auth_ceremony_session_id retired_at
  ).freeze

  class InvalidTransition < StandardError; end

  def self.browser_digest(surface:, entry_ref:, nonce:)
    raise ArgumentError, "browser nonce is invalid" unless nonce.is_a?(String)
    raise ArgumentError, "browser nonce is required" if nonce.blank?
    raise ArgumentError, "entry reference is invalid" unless entry_ref.is_a?(String)
    raise ArgumentError, "entry reference is required" if entry_ref.blank?

    Digest::SHA256.hexdigest("auth-admission:#{surface}:#{entry_ref}:#{nonce}")
  end

  included do
    class_attribute :auth_admission_surface_name, instance_accessor: false
    class_attribute :auth_admission_parent_classes, instance_accessor: false, default: {}.freeze
    class_attribute :auth_admission_base_token_class, instance_accessor: false
    class_attribute :auth_admission_session_class, instance_accessor: false

    validates :entry_ref, presence: true, uniqueness: true
    validates :purpose, presence: true
    validates :base_browser_digest, presence: true, length: { is: 64 }
    validates :expires_at, :created_at, :updated_at, presence: true
    validate :validate_parent_shape
    validate :validate_purpose_parent
    validate :validate_base_token_requirement
    validate :validate_auth_proof_pair
    validate :validate_redemption_pair
    validate :validate_terminal_exclusivity
    before_update :reject_immutable_fact_changes
  end

  class_methods do
    public

    def auth_admission_surface(surface = nil)
      self.auth_admission_surface_name = surface.to_s if surface
      auth_admission_surface_name
    end

    def configure_auth_admission_binding(surface:, sign_in_flow:, authorization_transaction:,
                                         step_up_ceremony_transaction:, base_token:, auth_session:)
      self.auth_admission_surface_name = surface.to_s
      self.auth_admission_parent_classes = {
        sign_in_flow: sign_in_flow,
        authorization_transaction: authorization_transaction,
        step_up_ceremony_transaction: step_up_ceremony_transaction,
      }.freeze
      self.auth_admission_base_token_class = base_token
      self.auth_admission_session_class = auth_session
    end

    def browser_digest(surface:, entry_ref:, nonce:)
      AuthAdmissionBinding.browser_digest(surface:, entry_ref:, nonce:)
    end

    def connection_owner
      if self <= AppTicketRecord
        AppTicketRecord
      elsif self <= ComTicketRecord
        ComTicketRecord
      elsif self <= OrgTicketRecord
        OrgTicketRecord
      else
        ActiveRecord::Base
      end
    end
  end

  public

  def parent_count
    [sign_in_flow_id, authorization_transaction_id, step_up_ceremony_transaction_id].compact.one? ? 1 : 0
  end

  def parent_kind
    return :sign_in_flow if sign_in_flow_id.present?
    return :authorization_transaction if authorization_transaction_id.present?
    return :step_up_ceremony_transaction if step_up_ceremony_transaction_id.present?

    nil
  end

  def live?(now: nil)
    decision_time = now || self.class.database_now
    retired_at.nil? && redeemed_at.nil? && expires_at > decision_time
  end

  def expired?(now: nil)
    decision_time = now || self.class.database_now
    expires_at <= decision_time
  end

  def confirmed?
    base_confirmed_at.present?
  end

  def attached?
    auth_ceremony_session_id.present? && confirmation_ref.present?
  end

  def redeemed?
    redeemed_at.present?
  end

  def retired?
    retired_at.present?
  end

  # Attaches one currently active, unadmitted Auth session and records a fresh
  # confirmation lookup reference. The binding row is locked before the Auth
  # session, matching the admission lock order.
  def attach_auth_session!(auth_session:, confirmation_ref:, now: nil)
    require_uuid!(confirmation_ref, "confirmation reference")
    ensure_configured_session!(auth_session)

    writing_connection do
      with_lock do
        decision_time = now || self.class.database_now
        if attached?
          return self if auth_ceremony_session_id == auth_session.id && self.confirmation_ref == confirmation_ref

          raise InvalidTransition, "auth ceremony session is already attached"
        end
        raise InvalidTransition, "binding is not live" unless live?(now: decision_time)
        raise InvalidTransition,
              "binding proof is partial" if auth_ceremony_session_id.present? || self.confirmation_ref.present?

        auth_session.with_lock do
          raise InvalidTransition,
                "auth ceremony session is unavailable" unless auth_session.active?(now: decision_time)
          raise InvalidTransition, "auth ceremony session is already admitted" if auth_session.admitted?

          duplicate = self.class.where(auth_ceremony_session_id: auth_session.id).where.not(id: id).exists?
          raise InvalidTransition, "auth ceremony session is already bound" if duplicate

          with_transition_write do
            update!(
              auth_ceremony_session_id: auth_session.id,
              confirmation_ref: confirmation_ref,
              updated_at: decision_time,
            )
          end
        end
      end
    end
  end

  # Confirms the Base browser nonce after the Auth side has attached its
  # session. Confirmation is intentionally one-way and idempotent only for the
  # same durable binding state.
  def confirm_base!(base_token:, browser_digest:, now: nil)
    ensure_configured_token!(base_token) if base_token

    writing_connection do
      with_lock do
        decision_time = now || self.class.database_now
        if confirmed?
          return self if base_confirmed_at <= decision_time && base_token_id == base_token&.id &&
            base_browser_digest == browser_digest.to_s

          raise InvalidTransition, "Base confirmation is already fixed"
        end
        raise InvalidTransition, "binding is not live" unless live?(now: decision_time)
        raise InvalidTransition, "Auth attachment is required" unless attached?
        raise InvalidTransition, "Base token does not match binding" unless base_token_id == base_token&.id
        raise InvalidTransition, "browser binding digest mismatch" unless base_browser_digest == browser_digest.to_s

        with_transition_write { update!(base_confirmed_at: decision_time, updated_at: decision_time) }
      end
    end
  end

  # Marks the binding redeemed only after the Auth session has been rotated and
  # admitted. The original attached session may already be revoked by that
  # rotation; its identity remains part of the durable proof tuple.
  def redeem!(auth_session:, admitted_auth_session:, now: nil)
    ensure_configured_session!(auth_session)
    ensure_configured_session!(admitted_auth_session)

    writing_connection do
      with_lock do
        decision_time = now || self.class.database_now
        if redeemed?
          return self if admitted_auth_ceremony_session_id == admitted_auth_session.id

          raise InvalidTransition, "binding is already redeemed"
        end
        raise InvalidTransition, "binding is retired" if retired?
        raise InvalidTransition, "binding is expired" unless expires_at > decision_time
        raise InvalidTransition, "Base confirmation is required" unless confirmed?
        raise InvalidTransition,
              "Auth session does not match binding" unless auth_ceremony_session_id == auth_session.id
        raise InvalidTransition, "Auth session was not admitted" unless admitted_auth_session.admitted?
        raise InvalidTransition,
              "admitted Auth session is unavailable" unless admitted_auth_session.active?(now: decision_time)
        raise InvalidTransition, "redemption proof is partial" if admitted_auth_ceremony_session_id.present?

        with_transition_write do
          update!(
            redeemed_at: decision_time,
            admitted_auth_ceremony_session_id: admitted_auth_session.id,
            updated_at: decision_time,
          )
        end
      end
    end
  end

  # Expired or superseded unredeemed rows are retired explicitly before a new
  # binding is issued. Terminal facts are never cleared or rewritten.
  def retire!(now: nil)
    writing_connection do
      with_lock do
        decision_time = now || self.class.database_now
        return self if retired?
        raise InvalidTransition, "redeemed binding cannot be retired" if redeemed?

        with_transition_write { update!(retired_at: decision_time, updated_at: decision_time) }
      end
    end
  end

  private

  def writing_connection(&)
    self.class.connection_owner.connected_to(role: :writing, &)
  end

  def with_transition_write
    @binding_transition_write = true
    yield
  ensure
    @binding_transition_write = false
  end

  def reject_immutable_fact_changes
    changed_columns = changes.keys & IMMUTABLE_FACT_COLUMNS
    return true if changed_columns.empty? || @binding_transition_write

    raise InvalidTransition, "admission binding facts are immutable: #{changed_columns.join(", ")}"
  end

  def validate_parent_shape
    return if parent_count == 1

    errors.add(:base, "exactly one admission parent is required")
  end

  def validate_purpose_parent
    return if parent_kind.nil? || purpose.blank?
    return if PARENT_PURPOSES.fetch(parent_kind).include?(purpose)

    errors.add(:purpose, "does not match admission parent")
  end

  def validate_base_token_requirement
    return unless BASE_TOKEN_PURPOSES.include?(purpose)
    return if base_token_id.present?

    errors.add(:base_token_id, "is required for this admission purpose")
  end

  def validate_auth_proof_pair
    return if auth_ceremony_session_id.blank? && confirmation_ref.blank?
    return if auth_ceremony_session_id.present? && confirmation_ref.present?

    errors.add(:base, "Auth session and confirmation reference must be supplied together")
  end

  def validate_redemption_pair
    return if redeemed_at.blank? && admitted_auth_ceremony_session_id.blank?
    return if redeemed_at.present? && admitted_auth_ceremony_session_id.present?

    errors.add(:base, "redemption timestamp and admitted session must be supplied together")
  end

  def validate_terminal_exclusivity
    return unless redeemed_at.present? && retired_at.present?

    errors.add(:base, "redeemed and retired states are mutually exclusive")
  end

  def ensure_configured_session!(session)
    expected = self.class.auth_admission_session_class
    raise InvalidTransition, "Auth session type mismatch" unless expected && session.is_a?(expected)
  end

  def ensure_configured_token!(token)
    expected = self.class.auth_admission_base_token_class
    raise InvalidTransition, "Base token type mismatch" unless expected && token.is_a?(expected)
  end

  def require_uuid!(value, label)
    UUIDTools::UUID.parse(value.to_s)
  rescue NameError
    unless value.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
      raise InvalidTransition, "#{label} is invalid"
    end
  rescue StandardError
    raise InvalidTransition, "#{label} is invalid"
  end
end
