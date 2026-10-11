# typed: false
# frozen_string_literal: true

module OidcAuthorizationTransactionable
  extend ActiveSupport::Concern

  STATUS_PENDING = "pending"
  STATUS_AUTHENTICATED = "authenticated"
  STATUS_CONSUMED = "consumed"
  STATUSES = [STATUS_PENDING, STATUS_AUTHENTICATED, STATUS_CONSUMED].freeze
  RETENTION_PERIOD = 15.minutes

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
    validates :intent, inclusion: { in: %w(sign_in sign_up invitation reauthentication step_up) }
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
                            expires_at:, prompt: nil, max_age: nil, now: Time.current)
      connection_owner.connected_to(role: :writing) do
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
          created_at: now,
          updated_at: now,
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
                               now: Time.current)
    raise ArgumentError, "authentication event time is required" if authentication_event_at.blank?

    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        raise ArgumentError, "authorization transaction expired" if locked.expired?(now: now)
        raise ArgumentError, "authorization transaction expired" if locked.login_challenge_expired?(now: now)
        raise ArgumentError, "authorization transaction already consumed" if locked.consumed?

        locked.update!(
          actor_ref: actor_ref.to_s,
          session_ref: session_ref.to_s,
          auth_method: auth_method.to_s,
          acr: acr.to_s.presence || "aal1",
          authenticated_at: authentication_event_at,
          status: STATUS_AUTHENTICATED,
        )
        locked
      end
    end
  end

  def consume!(now: Time.current)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        raise ArgumentError, "authorization transaction expired" if locked.expired?(now: now)
        raise ArgumentError, "authorization transaction is not authenticated" unless locked.authenticated?
        raise ArgumentError, "authorization transaction already consumed" if locked.consumed?

        locked.update!(
          consumed_at: now,
          status: STATUS_CONSUMED,
        )
        locked
      end
    end
  end

  def acme_resume_url
    origin = Oidc::AcmeServiceOrigin.from(
      Rails.configuration.x.boot_config.fetch(:hosts).base_service.to_s,
      default_scheme: "https",
    )
    origin.authorization_endpoint(query: { login_challenge: login_challenge })
  end

  private

  def transaction_surface_matches_class
    return if self.class.oidc_authorization_surface.blank?
    return if surface == self.class.oidc_authorization_surface

    errors.add(:surface, "does not match transaction store")
  end
end
