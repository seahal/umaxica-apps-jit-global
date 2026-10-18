# typed: false
# frozen_string_literal: true

class OidcAuthorizationTransactionCoordinator < ApplicationService
  Issuance = Data.define(:transaction)
  AdmissionIssuance = Data.define(:transaction, :handoff)

  class << self
    public

    def model_for(surface)
      case surface.to_s
      when "app" then ClientOidcAuthorizationTransaction
      when "com" then VisitorOidcAuthorizationTransaction
      when "org" then OperatorOidcAuthorizationTransaction
      else
        raise ArgumentError, "unsupported OIDC authorization surface: #{surface.inspect}"
      end
    end

    def issue!(surface:, intent:, params:, login_challenge: SecureRandom.urlsafe_base64(32),
               now: nil, login_challenge_ttl: 10.minutes, ttl: 15.minutes)
      model = model_for(surface)
      decision_time = now || model.database_now
      transaction =
        model.create_transaction!(
          surface: surface,
          intent: intent,
          client_id: params.fetch(:client_id),
          redirect_uri: params.fetch(:redirect_uri),
          response_type: params.fetch(:response_type),
          scope: params.fetch(:scope),
          state: params.fetch(:state),
          nonce: params.fetch(:nonce),
          code_challenge: params.fetch(:code_challenge),
          code_challenge_method: params.fetch(:code_challenge_method),
          prompt: OidcAuthorizeRequestResolver.normalize_prompt(params[:prompt]),
          max_age: OidcAuthorizeRequestResolver.normalize_max_age(params[:max_age]),
          login_challenge: login_challenge,
          login_challenge_expires_at: decision_time + login_challenge_ttl,
          expires_at: decision_time + ttl,
          now: decision_time,
        )
      Issuance.new(transaction: transaction)
    end

    # Parent creation and its Base admission binding are one Ticket transaction. A Valkey
    # delivery left behind by a rollback is unusable because no durable binding survives it.
    def issue_with_handoff!(surface:, intent:, params:, base_browser_nonce:, base_token:,
                            restart_of: nil,
                            login_challenge: SecureRandom.urlsafe_base64(32),
                            now: nil, login_challenge_ttl: 10.minutes, ttl: 15.minutes)
      model = model_for(surface)
      model.connection_owner.connected_to(role: :writing) do
        SignUpEmailPendingGuard.with_lock(
          namespace: "oidc:base_admission_initiation",
          address_digest: Digest::SHA256.hexdigest(
            [surface, intent, params.fetch(:client_id), params.fetch(:state), base_browser_nonce,
             base_token&.id,].to_json,
          ),
          model_class: model,
        ) do
          transaction = matching_admission_parent(
            model:, surface:, intent:, params:, base_browser_nonce:, base_token:, restart_of:,
          ) || issue!(
            surface:, intent:, params:, login_challenge:, now:, login_challenge_ttl:, ttl:,
          ).transaction
          handoff = BaseAuthAdmissionCoordinator.issue_handoff!(
            transaction:, base_browser_nonce:, base_token:, restart_of:,
          )
          AdmissionIssuance.new(transaction:, handoff:)
        end
      end
    end

    private

    def matching_admission_parent(model:, surface:, intent:, params:, base_browser_nonce:, base_token:, restart_of:)
      facts = {
        surface: surface,
        intent: intent,
        client_id: params.fetch(:client_id),
        redirect_uri: params.fetch(:redirect_uri),
        response_type: params.fetch(:response_type),
        scope: params.fetch(:scope),
        state: params.fetch(:state),
        nonce: params.fetch(:nonce),
        code_challenge: params.fetch(:code_challenge),
        code_challenge_method: params.fetch(:code_challenge_method),
        oidc_prompt: OidcAuthorizeRequestResolver.normalize_prompt(params[:prompt]),
        oidc_max_age: OidcAuthorizeRequestResolver.normalize_max_age(params[:max_age]),
        status: "pending",
      }
      time = model.database_now
      parents = model.where(facts).where("expires_at > ? AND login_challenge_expires_at > ?", time, time)
      bindings = BaseAuthAdmissionCoordinator.admission_binding_model(surface).where(
        authorization_transaction_id: parents.select(:id), base_token_id: base_token&.id,
        retired_at: nil, redeemed_at: nil,
      )
      if restart_of.present?
        original = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: restart_of)
        bindings = bindings.where(id: original.id)
      end
      matches =
        bindings.select do |binding|
          ActiveSupport::SecurityUtils.secure_compare(
            binding.base_browser_digest,
            AuthAdmissionBinding.browser_digest(surface:, entry_ref: binding.entry_ref, nonce: base_browser_nonce),
          )
        end
      if matches.length > 1
        raise BaseAuthAdmissionCoordinator::Denied.new("ambiguous admission initiation", code: "invalid_admission")
      end
      if restart_of.present? && matches.empty?
        raise BaseAuthAdmissionCoordinator::Denied.new("admission restart is unavailable", code: "invalid_admission")
      end

      model.lock.find(matches.first.authorization_transaction_id) if matches.one?
    end

    public

    def find_by_login_challenge!(surface:, login_challenge:)
      model_for(surface).find_by!(login_challenge: login_challenge)
    end

    def find_by_transaction_id!(surface:, transaction_id:)
      model_for(surface).find_by!(transaction_id: transaction_id)
    end

    def register_result!(surface:, login_challenge:, actor:, session_ref:, auth_method:, acr: nil,
                         authentication_event_at: nil, now: nil)
      transaction = find_by_login_challenge!(surface: surface, login_challenge: login_challenge)
      transaction = transaction.register_authentication!(
        actor_ref: actor.public_id,
        session_ref: session_ref,
        auth_method: auth_method,
        acr: acr,
        authentication_event_at: authentication_event_at,
        now: now,
      )
      Issuance.new(transaction: transaction)
    end

    def consume!(surface:, login_challenge:, now: nil)
      find_by_login_challenge!(surface: surface, login_challenge: login_challenge).consume!(now: now)
    end

    private :find_by_login_challenge!
  end
end
