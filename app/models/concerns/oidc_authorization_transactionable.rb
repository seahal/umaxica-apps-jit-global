# typed: false
# frozen_string_literal: true

module OidcAuthorizationTransactionable
  extend ActiveSupport::Concern

  STATUS_PENDING = "pending"
  STATUS_AUTHENTICATED = "authenticated"
  STATUS_CONSUMED = "consumed"
  STATUSES = [STATUS_PENDING, STATUS_AUTHENTICATED, STATUS_CONSUMED].freeze
  RETENTION_PERIOD = 15.minutes
  RESULT_TTL = 60.seconds

  included do
    class_attribute :oidc_authorization_surface_name, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes

    scope :pending, -> { where(status: STATUS_PENDING) }
    scope :authenticated, -> { where(status: STATUS_AUTHENTICATED) }
    scope :consumed, -> { where(status: STATUS_CONSUMED) }
    scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time)) }

    validates :transaction_id, :surface, :intent, :client_id, :redirect_uri, :response_type, :scope, :state,
              :nonce, :code_challenge, :code_challenge_method, :login_challenge, :login_challenge_expires_at,
              :expires_at, :status, presence: true
    validates :surface, inclusion: { in: %w(app com org) }
    validates :intent, inclusion: { in: %w(authentication sign_in sign_up invitation reauthentication step_up) }
    validates :response_type, inclusion: { in: ["code"] }
    validates :oidc_prompt, inclusion: { in: OidcAuthorizeRequestResolver::SUPPORTED_PROMPTS }, allow_nil: true
    validates :oidc_max_age, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :code_challenge_method, inclusion: { in: ["S256"] }
    validates :status, inclusion: { in: STATUSES }
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
      connection_owner.connected_to(role: :writing) do
        decision_time = now || connection_owner.database_now

        create!(
          transaction_id: SecureRandom.uuid,
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
          status: STATUS_PENDING,
          created_at: decision_time,
          updated_at: decision_time,
        )
      end
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

  def authenticated?
    status == STATUS_AUTHENTICATED
  end

  def consumed?
    status == STATUS_CONSUMED
  end

  def expired?(now: Time.current)
    expires_at.to_i <= now.to_i
  end

  def login_challenge_expired?(now: Time.current)
    login_challenge_expires_at.to_i <= now.to_i
  end

  # PostgreSQL records the current result generation and digest before the raw
  # result is placed in Valkey. Valkey is transport only; a failed issue can be
  # retried with a newer generation without changing actor authentication data.
  def prepare_result_delivery!(result_digest:, ttl: RESULT_TTL, now: nil)
    raise ArgumentError, "result digest is required" if result_digest.to_s.blank?

    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        decision_time = now || self.class.database_now
        raise ArgumentError, "authorization transaction expired" if locked.expired?(now: decision_time)
        raise ArgumentError, "authorization transaction is not authenticated" unless locked.authenticated?
        raise ArgumentError, "authorization result is already finalized" if locked.base_finalized_at.present?

        generation = locked.result_generation.to_i + 1
        locked.update!(
          result_generation: generation,
          result_digest: result_digest.to_s,
          result_expires_at: decision_time + ttl,
          result_consumed_at: nil,
          updated_at: decision_time,
        )
        [locked, generation]
      end
    end
  end

  def result_delivery_matches?(result_digest:, result_generation:, now: nil)
    decision_time = now || self.class.database_now
    return false if result_digest.blank? || result_digest.to_s.length != 64
    return false unless result_generation.to_i == self[:result_generation].to_i
    return false if result_expires_at.blank? || result_expires_at <= decision_time
    return false unless result_digest.to_s.match?(/\A[0-9a-f]{64}\z/i)

    ActiveSupport::SecurityUtils.secure_compare(self[:result_digest].to_s, result_digest.to_s)
  end

  # Base finalization is serialized by the surface-local transaction row. The
  # block performs the surface-specific Browser Session operation and returns a
  # successful browser_session_ref. Retries reuse the persisted reference.
  def finalize_base!(now: nil)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        decision_time = now || self.class.database_now
        raise ArgumentError, "authorization transaction expired" if locked.expired?(now: decision_time)
        raise ArgumentError, "authorization transaction is not authenticated" unless locked.authenticated? ||
          locked.base_finalized_at.present?

        result = yield(locked, decision_time)
        if result.is_a?(Hash) && result[:status] == :success && result[:browser_session_ref].present? &&
            locked.base_finalized_at.blank?
          browser_session_ref = result[:browser_session_ref].to_s
          raise ArgumentError, "browser session reference is required" if browser_session_ref.blank?

          locked.update!(
            browser_session_ref: browser_session_ref,
            result_consumed_at: decision_time,
            base_finalized_at: decision_time,
            status: STATUS_CONSUMED,
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
  def claim_authorization_grant!(now: nil)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        decision_time = now || self.class.database_now
        locked.claim_authorization_grant_locked!(now: decision_time)
      end
    end
  end

  # The caller must already hold a row lock in the surface ticket database.
  # Keeping this primitive separate lets token exchange claim the durable grant
  # in the same transaction that creates the RP Session.
  def claim_authorization_grant_locked!(now:)
    raise ArgumentError, "authorization transaction expired" if expired?(now: now)
    raise ArgumentError, "authorization transaction is not finalized" if base_finalized_at.blank?

    return false if authorization_grant_redeemed_at.present?

    update!(authorization_grant_redeemed_at: now, updated_at: now)
    true
  end

  def authorize_params
    {
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
  end

  def register_authentication!(actor_ref:, session_ref:, auth_method:, acr:, authentication_event_at: nil,
                               now: nil)
    raise ArgumentError, "authentication event time is required" if authentication_event_at.blank?

    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        decision_time = now || self.class.database_now
        raise ArgumentError, "authorization transaction expired" if locked.expired?(now: decision_time)
        raise ArgumentError, "authorization transaction expired" if locked.login_challenge_expired?(
          now: decision_time,
        )
        raise ArgumentError, "authorization transaction is not pending" unless locked.status == STATUS_PENDING

        locked.update!(
          actor_ref: actor_ref.to_s,
          session_ref: session_ref.to_s.presence,
          auth_method: auth_method.to_s,
          acr: acr.to_s.presence || "aal1",
          authenticated_at: authentication_event_at,
          status: STATUS_AUTHENTICATED,
          updated_at: decision_time,
        )
        locked
      end
    end
  end

  def consume!(now: nil)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        decision_time = now || self.class.database_now
        raise ArgumentError, "authorization transaction expired" if locked.expired?(now: decision_time)
        raise ArgumentError, "authorization transaction is not authenticated" unless locked.authenticated?
        raise ArgumentError, "authorization transaction already consumed" if locked.consumed?

        locked.update!(
          consumed_at: decision_time,
          status: STATUS_CONSUMED,
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
