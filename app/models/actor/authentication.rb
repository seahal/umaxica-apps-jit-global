# typed: false
# frozen_string_literal: true

class Actor
  class Authentication
    attr_reader :login_public_id, :access_claims, :acr, :amr, :actor_type, :actor_id,
                :active_sign_sequence_id

    def initialize(login_public_id: nil, access_claims: nil, acr: nil, amr: [],
                   actor_type: nil, actor_id: nil, restricted: false, active_sign_sequence_id: nil)
      @login_public_id = login_public_id
      @access_claims = immutable_claims(access_claims)
      @acr = acr
      @amr = Array(amr).freeze
      @actor_type = actor_type&.to_sym
      @actor_id = actor_id
      @restricted = restricted
      @active_sign_sequence_id = active_sign_sequence_id
      freeze
    end

    def null?
      login_public_id.blank? && access_claims.blank?
    end

    def signed_in?
      login_public_id.present? && actor_type.present? && actor_type != :unauthenticated
    end

    def aal
      acr&.to_sym
    end

    def aal1?
      aal == :aal1
    end

    def restricted?
      @restricted || acr.to_s == "restricted"
    end

    # Which sign-in ceremony established this session, derived from the signed
    # access token rather than passed in: every construction site already
    # carries the claims, and a caller must not be able to assert a context the
    # token does not.
    #
    # Distinct from #restricted?, which is the session-limit remediation state.
    def authentication_context
      AuthenticationContextValue.from_claims(access_claims)
    end

    delegate :emergency?, to: :authentication_context

    def verified?
      amr.present? || acr.present?
    end

    def ==(other)
      other.is_a?(self.class) &&
        login_public_id == other.login_public_id &&
        access_claims == other.access_claims &&
        acr == other.acr &&
        amr == other.amr &&
        actor_type == other.actor_type &&
        actor_id == other.actor_id &&
        restricted? == other.restricted? &&
        active_sign_sequence_id == other.active_sign_sequence_id
    end

    alias eql? ==

    def hash
      [
        self.class,
        login_public_id,
        access_claims,
        acr,
        amr,
        actor_type,
        actor_id,
        restricted?,
        active_sign_sequence_id,
      ].hash
    end

    private

    def immutable_claims(value)
      case value
      when Hash
        value.transform_values { |entry| immutable_claims(entry) }.freeze
      when Array
        value.map { |entry| immutable_claims(entry) }.freeze
      else
        value
      end
    end

    NULL = new.freeze
  end

  Authn = Authentication
end
