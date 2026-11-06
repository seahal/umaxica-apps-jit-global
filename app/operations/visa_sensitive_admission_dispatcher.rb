# frozen_string_literal: true

# Dispatches an O-9 authorization request to the Auth binding created by Visa.
# The OIDC state locates the request; the saved request and live admission must also match.
class VisaSensitiveAdmissionDispatcher
  Dispatch = Data.define(:surface, :entry_ref)

  class InvalidRequest < StandardError; end

  CONFIG = {
    "app" => [
      [ClientVisaSensitiveAdmission, "passkey_registration", "none", ClientAuthAdmissionBinding],
      [ClientVisaSocialLinkAdmission, "social_link", nil, ClientAuthAdmissionBinding],
    ],
    "org" => [
      [OperatorVisaSensitiveAdmission, "passkey_registration", "none", OperatorAuthAdmissionBinding],
    ],
  }.freeze

  class << self
    def call!(surface:, params:, validated_request:)
      new(surface:, params:, validated_request:).call
    end
  end

  def initialize(surface:, params:, validated_request:)
    @surface = surface.to_s
    @params = params.to_h.symbolize_keys
    @validated_request = validated_request
  end

  def call
    candidates = CONFIG.fetch(surface)
    owner = candidates.first.first.connection_owner
    owner.connected_to(role: :writing) do
      owner.transaction do
        matches = candidates.flat_map { |candidate| find_matches(candidate) }
        raise InvalidRequest unless matches.length <= 1

        if matches.empty?
          nil
        else
          admission, authorization, purpose, provider, binding_class = matches.first
          validate_match!(admission, authorization, purpose:, provider:, binding_class:)
          Dispatch.new(surface:, entry_ref: binding_class.find(admission.auth_admission_binding_id).entry_ref)
        end
      end
    end
  rescue ActiveRecord::RecordNotFound, KeyError, TypeError
    raise InvalidRequest
  end

  private

  attr_reader :surface, :params, :validated_request

  def find_matches(candidate)
    admission_model, purpose, provider, = candidate
    authorization_model = admission_model.reflect_on_association(:oidc_authorization_transaction).klass
    admission_model.joins(:oidc_authorization_transaction)
      .where(authorization_model.table_name => { state: params.fetch(:state).to_s })
      .lock.to_a.map do |admission|
        authorization = authorization_model.find(admission.oidc_authorization_transaction_id)
        [admission, authorization, purpose, provider, candidate.fetch(3)]
      end
  end

  def validate_match!(admission, authorization, purpose:, provider:, binding_class:)
    now = admission.class.connection_owner.database_now
    binding = binding_class.find(admission.auth_admission_binding_id)
    request_matches = authorization.surface == surface && authorization.intent == "step_up" &&
      authorization.client_id == validated_request.client.client_id &&
      authorization.redirect_uri == params.fetch(:redirect_uri).to_s &&
      authorization.response_type == params.fetch(:response_type).to_s &&
      authorization.scope == validated_request.scope && authorization.state == params.fetch(:state).to_s &&
      authorization.nonce == params.fetch(:nonce).to_s &&
      authorization.code_challenge == params.fetch(:code_challenge).to_s &&
      authorization.code_challenge_method == params.fetch(:code_challenge_method).to_s &&
      authorization.oidc_prompt == validated_request.prompt && authorization.oidc_max_age == validated_request.max_age &&
      validated_request.step_up_requested
    provider_matches = provider ? admission.provider == provider : admission.provider.in?(%w(google apple))
    admission_matches = admission.realm == surface && admission.client_id == validated_request.client.client_id &&
      admission.purpose == purpose && provider_matches &&
      admission.status.in?(%w(issued browser_confirmed)) && admission.expires_at > now &&
      admission.rp_session_expires_at > now && !authorization.expired?(now:) &&
      !authorization.login_challenge_expired?(now:) && authorization.pending? &&
      binding.purpose == "credential_registration_handoff" && binding.live?(now:) &&
      binding.step_up_ceremony_transaction_id == admission.step_up_ceremony_transaction_id
    raise InvalidRequest unless request_matches && admission_matches
  end
end
