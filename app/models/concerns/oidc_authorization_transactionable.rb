# typed: false
# frozen_string_literal: true

module OidcAuthorizationTransactionable
  extend ActiveSupport::Concern

  STATUS_PENDING = 10
  STATUS_AUTHENTICATED = 20
  STATUS_CONSUMED = 30
  # D09: a user Cancel before authorization finalization; terminal from pending or authenticated.
  STATUS_CANCELED = 90
  STATUS_IDS = [STATUS_PENDING, STATUS_AUTHENTICATED, STATUS_CONSUMED, STATUS_CANCELED].freeze
  STATUS_NAMES = {
    STATUS_PENDING => "pending",
    STATUS_AUTHENTICATED => "authenticated",
    STATUS_CONSUMED => "consumed",
    STATUS_CANCELED => "canceled",
  }.freeze
  CANCELLATION_HANDOFF_REFERENCE = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
  CANCELLATION_HANDOFF_DIGEST = /\A[0-9a-f]{64}\z/
  RETENTION_PERIOD = 15.minutes
  RESULT_TTL = 10.seconds

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    class_attribute :oidc_authorization_surface_name, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes

    scope :pending, -> { where(status_id: STATUS_PENDING) }
    scope :authenticated, -> { where(status_id: STATUS_AUTHENTICATED) }
    scope :consumed, -> { where(status_id: STATUS_CONSUMED) }
    scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time)) }
    scope :purgeable_at, lambda { |time, retention_period: RETENTION_PERIOD|
      where(arel_table[:expires_at].lteq(time - retention_period))
    }

    validates :transaction_id, :surface, :intent, :client_id, :redirect_uri, :response_type, :scope, :state,
              :nonce, :code_challenge, :code_challenge_method, :login_challenge, :login_challenge_expires_at,
              :expires_at, :status_id, presence: true
    validates :surface, inclusion: { in: %w(app org) }
    validates :intent, inclusion: { in: %w(authentication sign_in sign_up invitation reauthentication step_up) }
    validates :response_type, inclusion: { in: ["code"] }
    validates :oidc_prompt, inclusion: { in: OidcAuthorizeRequestResolver::SUPPORTED_PROMPTS }, allow_nil: true
    validates :oidc_max_age, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :code_challenge_method, inclusion: { in: ["S256"] }
    validates :status_id, inclusion: { in: STATUS_IDS }
    validates :transaction_id, uniqueness: true
    validates :login_challenge, uniqueness: true
    validate :transaction_surface_matches_class
  end

  class_methods do
    def oidc_authorization_surface(value = nil)
      self.oidc_authorization_surface_name = value.to_s if value
      oidc_authorization_surface_name
    end

    def create_transaction!(surface:, intent:, client_id:, redirect_uri:, response_type:, scope:, state:, nonce:,
                            code_challenge:, code_challenge_method:, login_challenge:, login_challenge_expires_at:,
                            expires_at:, prompt: nil, max_age: nil, now: nil)
      retries = 0

      connection_owner.connected_to(role: :writing) do
        decision_time = now || connection_owner.database_now
        loop do
          attributes = authorization_transaction_attributes(
            transaction_id: PublicId.generate, surface: surface, intent: intent, client_id: client_id,
            redirect_uri: redirect_uri, response_type: response_type, scope: scope, state: state,
            nonce: nonce, code_challenge: code_challenge, code_challenge_method: code_challenge_method,
            prompt: prompt, max_age: max_age, login_challenge: login_challenge,
            login_challenge_expires_at: login_challenge_expires_at, expires_at: expires_at,
            decision_time: decision_time,
          )

          begin
            return transaction(requires_new: true) { create!(attributes) }
          rescue ActiveRecord::RecordInvalid => e
            raise unless generated_reference_collision_validation?(e)
          rescue ActiveRecord::RecordNotUnique => e
            raise unless generated_reference_collision?(e)
          end

          retries += 1
          raise if retries > PublicId::MAX_COLLISION_RETRIES
        end
      end
    end

    def connection_owner
      if self <= OpBaseAppRecord
        OpBaseAppRecord
      elsif self <= OpBaseOrgRecord
        OpBaseOrgRecord
      else
        ActiveRecord::Base
      end
    end

    private

    def authorization_transaction_attributes(transaction_id:, surface:, intent:, client_id:, redirect_uri:,
                                             response_type:, scope:, state:, nonce:, code_challenge:,
                                             code_challenge_method:, prompt:, max_age:, login_challenge:,
                                             login_challenge_expires_at:, expires_at:, decision_time:)
      {
        transaction_id: transaction_id,
        surface: surface.to_s,
        intent: intent.to_s,
        client_id: client_id.to_s,
        redirect_uri: redirect_uri.to_s,
        response_type: response_type.to_s,
        scope: scope.to_s,
        state: state.to_s,
        nonce: nonce.to_s,
        code_challenge: code_challenge.to_s,
        code_challenge_method: code_challenge_method.to_s,
        oidc_prompt: prompt.presence,
        oidc_max_age: max_age.presence,
        login_challenge: login_challenge.to_s,
        login_challenge_expires_at: login_challenge_expires_at,
        expires_at: expires_at,
        status_id: STATUS_PENDING,
        created_at: decision_time,
        updated_at: decision_time,
      }
    end

    def generated_reference_collision_validation?(error)
      error.record.errors.of_kind?(:transaction_id, :taken)
    end

    def generated_reference_collision?(error)
      result = error.cause&.result
      return false unless result

      constraint = result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      lease_connection.schema_cache.indexes(table_name).any? do |index|
        index.name == constraint && index.unique && index.where.nil? && index.columns == ["transaction_id"]
      end
    end
  end

  public

  def status_name
    STATUS_NAMES.fetch(status_id) do
      raise ArgumentError, "unknown OIDC authorization transaction status: #{status_id.inspect}"
    end
  end

  def pending?
    status_id == STATUS_PENDING
  end

  def authenticated?
    status_id == STATUS_AUTHENTICATED
  end

  def consumed?
    status_id == STATUS_CONSUMED
  end

  def canceled?
    status_id == STATUS_CANCELED
  end

  def base_finalized?
    base_finalized_at.present? && browser_session_ref.present?
  end

  def cancellation_handoff_available?(now: nil)
    now ||= self.class.database_now
    available_state =
      case status_id
      when STATUS_PENDING, STATUS_AUTHENTICATED
        !base_finalized?
      when STATUS_CANCELED
        !base_finalized? && cancellation_handoff_ref.present? && cancellation_handoff_ciphertext.present?
      else
        false
      end
    available_state && !expired?(now: now)
  end

  # Binds the encrypted Auth-to-Base cancellation handoff to this unfinalized parent. Re-binding the
  # same handoff is idempotent; a different one is refused.
  def prepare_cancellation_handoff!(reference:, ciphertext:)
    unless reference.is_a?(String) && reference.match?(CANCELLATION_HANDOFF_REFERENCE) &&
        ciphertext.is_a?(String) && ciphertext.present?
      raise ArgumentError, "invalid cancellation handoff"
    end

    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        decision_time = self.class.database_now
        raise ArgumentError, "authorization transaction is not cancellable" unless
          locked.cancellation_handoff_available?(now: decision_time)

        if locked.cancellation_handoff_ref.present?
          return locked if locked.cancellation_handoff_ref == reference &&
            locked.cancellation_handoff_ciphertext == ciphertext

          raise ArgumentError, "cancellation handoff is already bound"
        end

        locked.update!(
          cancellation_handoff_ref: reference, cancellation_handoff_ciphertext: ciphertext,
          updated_at: decision_time,
        )
        locked
      end
    end
  end

  # Commits Cancel while the authorization parent is pending or authenticated but not finalized.
  # A later authentication result for a canceled parent is refused by register_authentication!.
  def cancel!(cancellation_handoff_digest:)
    unless cancellation_handoff_digest.is_a?(String) && cancellation_handoff_digest.match?(CANCELLATION_HANDOFF_DIGEST)
      raise ArgumentError, "invalid cancellation handoff digest"
    end

    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        if locked.canceled?
          return locked if locked.cancellation_handoff_digest == cancellation_handoff_digest

          raise ArgumentError, "authorization transaction was canceled by another handoff"
        end

        decision_time = self.class.database_now
        raise ArgumentError, "authorization transaction is not cancellable" unless
          locked.cancellation_handoff_available?(now: decision_time)
        raise ArgumentError, "cancellation handoff is not bound" if locked.cancellation_handoff_ref.blank?

        locked.update!(
          status_id: STATUS_CANCELED, canceled_at: decision_time,
          cancellation_handoff_digest: cancellation_handoff_digest, updated_at: decision_time,
        )
        locked
      end
    end
  end

  def expired?(now: Time.current)
    expires_at <= now
  end

  def login_challenge_expired?(now: Time.current)
    login_challenge_expires_at <= now
  end

  # PostgreSQL records the current result generation and digest before the raw
  # result is placed in Valkey. Valkey is transport only; a failed issue can be
  # retried with a newer generation without changing actor authentication data.
  def prepare_result_delivery!(result_digest:, ttl: RESULT_TTL, expires_at_cap: nil)
    raise ArgumentError, "result digest is required" if result_digest.to_s.blank?

    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        decision_time = self.class.database_now
        raise ArgumentError, "authorization transaction expired" if locked.expired?(now: decision_time)
        raise ArgumentError,
              "authorization login challenge expired" if locked.login_challenge_expired?(now: decision_time)
        raise ArgumentError, "authorization transaction is not authenticated" unless locked.authenticated?
        raise ArgumentError, "authorization result is already finalized" if locked.base_finalized_at.present?
        if expires_at_cap && expires_at_cap <= decision_time
          raise ArgumentError, "authorization result lifetime expired"
        end

        generation = locked.result_generation.to_i + 1
        locked.update!(
          result_generation: generation,
          result_digest: result_digest.to_s,
          result_expires_at: [decision_time + ttl, locked.expires_at, locked.login_challenge_expires_at,
                              expires_at_cap,].compact.min,
          result_consumed_at: nil,
          updated_at: decision_time,
        )
        [locked, generation]
      end
    end
  end

  def result_delivery_matches?(result_digest:, result_generation:, now: nil)
    decision_time = now || self.class.database_now
    return false unless authenticated? || consumed?
    return false unless result_digest.is_a?(String) && result_digest.match?(/\A[0-9a-f]{64}\z/)
    return false unless result_generation.is_a?(Integer) && result_generation.positive?
    return false unless self.result_digest && result_expires_at && result_expires_at > decision_time
    return false if expired?(now: decision_time) || login_challenge_expired?(now: decision_time)

    self.result_generation == result_generation &&
      ActiveSupport::SecurityUtils.secure_compare(self.result_digest, result_digest)
  end

  # Base finalization is serialized by the surface-local transaction row. The
  # block performs the surface-specific Browser Session operation and returns a
  # successful browser_session_ref. Retries reuse the persisted reference.
  def finalize_base!(result_generation: nil)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        decision_time = self.class.database_now
        raise ArgumentError, "authorization transaction expired" if locked.expired?(now: decision_time)
        raise ArgumentError, "authorization transaction is not authenticated" unless
          locked.authenticated? || (locked.consumed? && locked.base_finalized?)
        if result_generation.present? && locked.result_generation.to_i != Integer(result_generation)
          raise ArgumentError, "authorization result generation is stale"
        end

        result = yield(locked, decision_time)
        if result.is_a?(Hash) && result[:status] == :success && result[:browser_session_ref].present? &&
            !locked.base_finalized?
          browser_session_ref = result[:browser_session_ref].to_s
          raise ArgumentError, "browser session reference is required" if browser_session_ref.blank?

          locked.update!(
            browser_session_ref: browser_session_ref,
            result_consumed_at: decision_time,
            base_finalized_at: decision_time,
            status_id: STATUS_CONSUMED,
            consumed_at: decision_time,
            updated_at: decision_time,
          )
        end
        result
      end
    end
  end

  # The durable authorization grant is redeemed in the same surface ticket
  # database as the RP Session. A Valkey code is transport cleanup, not the
  # correctness authority for this one-time transition.
  def claim_authorization_grant!
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        locked.claim_authorization_grant_locked!
      end
    end
  end

  # The caller must already hold a row lock in the surface ticket database.
  # Keeping this primitive separate lets token exchange claim the durable grant
  # in the same transaction that creates the RP Session.
  def claim_authorization_grant_locked!
    decision_time = self.class.database_now
    raise ArgumentError, "authorization transaction expired" if expired?(now: decision_time)
    raise ArgumentError, "authorization transaction is not finalized" unless consumed? && base_finalized?

    return false if authorization_grant_redeemed_at.present?

    update!(authorization_grant_redeemed_at: decision_time, updated_at: decision_time)
    true
  end

  def authorize_params
    params = {
      response_type: response_type,
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scope,
      state: state,
      nonce: nonce,
      code_challenge: code_challenge,
      code_challenge_method: code_challenge_method,
      prompt: oidc_prompt,
      max_age: oidc_max_age,
    }.compact
    params[:claims] = OidcAuthorizeRequestResolver::STEP_UP_CLAIMS if intent == "step_up"
    params
  end

  def register_authentication!(actor_ref:, session_ref:, auth_method:, acr:, authentication_event_at: nil)
    raise ArgumentError, "authentication event time is required" if authentication_event_at.blank?

    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        decision_time = self.class.database_now
        raise ArgumentError, "authorization transaction expired" if locked.expired?(now: decision_time)
        raise ArgumentError, "authorization transaction expired" if locked.login_challenge_expired?(
          now: decision_time,
        )
        raise ArgumentError, "authorization transaction is not pending" unless locked.pending?

        locked.update!(
          actor_ref: actor_ref.to_s,
          session_ref: session_ref.to_s.presence,
          auth_method: auth_method.to_s,
          acr: acr.to_s.presence || "aal1",
          authenticated_at: authentication_event_at,
          status_id: STATUS_AUTHENTICATED,
          updated_at: decision_time,
        )
        locked
      end
    end
  end

  def consume!
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        decision_time = self.class.database_now
        raise ArgumentError, "authorization transaction expired" if locked.expired?(now: decision_time)
        raise ArgumentError, "authorization transaction is not authenticated" unless locked.authenticated?
        raise ArgumentError, "authorization transaction already consumed" if locked.consumed?

        locked.update!(
          consumed_at: decision_time,
          status_id: STATUS_CONSUMED,
          updated_at: decision_time,
        )
        locked
      end
    end
  end

  private

  def transaction_surface_matches_class
    return if self.class.oidc_authorization_surface.blank?
    return if surface == self.class.oidc_authorization_surface

    errors.add(:surface, "does not match transaction store")
  end
end
