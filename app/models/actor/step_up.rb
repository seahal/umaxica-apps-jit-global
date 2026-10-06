# typed: false
# frozen_string_literal: true

class Actor
  StepUp =
    Data.define(
      :scope,
      # @deprecated Legacy AAL label only; remove with the AAL removal ledger after all consumers migrate.
      :required_aal,
      :allowed_methods,
      :satisfied,
      :satisfied_at,
      :expires_at,
      :usable_token,
      :method,
      :session_bound,
      :token_bound,
      :purpose,
      :audience,
      :purpose_bound,
      :audience_bound,
      :phishing_resistant_required,
      :user_verification_required,
      :full_reauthentication_required,
      :resource_bound,
      :tenant_bound,
    ) do
      def self.null = NULL

      def satisfied? = !!satisfied

      def usable_token? = !!usable_token

      def null?
        scope.blank? && required_aal.blank? && !satisfied? && satisfied_at.blank? && expires_at.blank?
      end
    end

  Actor::StepUp::NULL =
    Actor::StepUp.new(
      scope: nil,
      required_aal: nil,
      allowed_methods: [],
      satisfied: false,
      satisfied_at: nil,
      expires_at: nil,
      usable_token: false,
      method: nil,
      session_bound: false,
      token_bound: false,
      purpose: nil,
      audience: nil,
      purpose_bound: false,
      audience_bound: false,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      resource_bound: false,
      tenant_bound: false,
    ).freeze
end
