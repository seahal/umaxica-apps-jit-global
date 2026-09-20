# typed: false
# frozen_string_literal: true

module ExternalAuthenticationEndpoint
  extend ActiveSupport::Concern

  CEREMONY_REFERENCE_SESSION_KEY = :external_authentication_ceremony_reference

  private

  def external_authentication_allowed?(surface:, provider:, operation:)
    ExternalAuthentication::ProviderSurfacePolicy.new.allowed?(
      surface: surface, provider: provider,
      operation: operation,
    )
  end

  def external_authentication_start_available?(provider:, operation:, context:)
    decision = ExternalAuthentication::ProviderAvailabilityFactory.current
      .start_decision(provider: provider, operation: operation, context: context)
    decision.state == :enabled
  rescue Redis::BaseError => e
    log_external_authentication_availability_misconfiguration(phase: "start", provider: provider, error: e)
    false
  end

  def external_authentication_callback_available?(provider:, ceremony:, context:)
    decision = ExternalAuthentication::ProviderAvailabilityFactory.current
      .callback_decision(provider: provider, ceremony: ceremony, context: context)
    %i(enabled draining).include?(decision.state)
  rescue Redis::BaseError => e
    log_external_authentication_availability_misconfiguration(phase: "callback", provider: provider, error: e)
    false
  end

  # The gate stays closed when the flag store is unreadable, but say which feature is at fault.
  # Without this the caller only reports a generic provider error, which reads as an outage at the
  # provider rather than as a Flipper backing-store failure in this deployment.
  def log_external_authentication_availability_misconfiguration(phase:, provider:, error:)
    Rails.logger.error(
      JitLogEvent.format(
        "external_authentication.availability.misconfigured",
        phase: phase,
        provider: provider,
        error_class: error.class.name,
        error_message: error.message,
        expected_feature:
          ExternalAuthentication::FlipperProviderAvailabilityAdapter::PROVIDER_FEATURE_NAMES[provider],
      ),
    )
  end

  def external_authentication_method_locked?(enforcement_case_class:, principal_public_id:, authentication_method:)
    ExternalAuthentication::AuthenticationMethodLockPolicy.new.locked?(
      enforcement_case_class: enforcement_case_class,
      principal_public_id: principal_public_id,
      authentication_method: authentication_method,
    )
  end
end
