# typed: false
# frozen_string_literal: true

# Enforces Sign Entry Sentry at Auth's interactive entry boundary.  The concern
# is deliberately narrower than the Auth application controller: settings,
# re-verification, Sign Out and other ticket ceremonies do not become Sign In
# or Sign Up just because they live on the same host.
module SignEntrySentryEnforcement
  private

  def enforce_sign_entry_sentry!
    flow = sign_entry_sentry_flow_for_request
    return unless flow

    refuse_sign_entry_sentry!(flow:, enforcement_point: "auth_request") unless
      SignEntrySentryResolver.call(surface: auth_ceremony_surface, flow:).allowed?
  end

  # Ceremony binding attachment is a separate endpoint from the visual entry
  # pages.  It calls this method after resolving the server-side binding and
  # before it attaches or redeems anything.
  def enforce_sign_entry_sentry_for_binding!(binding)
    flow = sign_entry_sentry_flow_for_binding(binding)
    return false unless flow
    return false if SignEntrySentryResolver.call(surface: auth_ceremony_surface, flow:).allowed?

    refuse_sign_entry_sentry!(flow:, enforcement_point: "admission_binding")
    true
  end

  def sign_entry_sentry_flow_for_request
    path = controller_path.to_s
    if path.match?(%r{\Aauth/(?:app|com|org)/sign/(?:in|up)(?:/|\z)})
      return nil if path.include?("/emergency/")

      return path.match?(%r{/sign/up(?:/|\z)}) ? "sign_up" : "sign_in"
    end

    # Provider callbacks and provider request-phase controllers do not have a
    # sign/in or sign/up path.  Their Auth ceremony binding remains the source
    # of effective intent, so a callback cannot bypass a flag flip.
    return unless path.match?(%r{\Aauth/(?:app|org)/(?:omniauth|social)/})
    return "sign_up" if auth_ceremony_matches_intent?("sign_up")
    return "sign_in" if auth_ceremony_matches_intent?("sign_in")

    nil
  rescue ArgumentError, ActiveRecord::RecordNotFound
    nil
  end

  def sign_entry_sentry_flow_for_binding(binding)
    if binding.purpose == "authentication_handoff"
      transaction_record =
        case auth_ceremony_surface
        when "app" then ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        when "com" then VisitorOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        when "org" then OperatorOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        else raise ArgumentError, "unsupported Auth ceremony surface"
        end
      transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
        surface: auth_ceremony_surface,
        transaction_id: transaction_record.transaction_id,
      )
      return AuthEntryIntentResolver.call(
        prompt: transaction.oidc_prompt,
        entry_intent: binding.entry_intent,
      )
    end

    binding.entry_intent.to_s.presence
  rescue ActiveRecord::RecordNotFound, ArgumentError
    nil
  end

  def refuse_sign_entry_sentry!(flow:, enforcement_point:)
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    message_key = (flow.to_s == "sign_up") ? "sign_up_unavailable" : "sign_in_unavailable"
    record_sign_in_path_refusal!("sentry_blocked")
    # The Sentry runs before `set_locale`; the requested language (already resolved into
    # `requested_context`) decides the text so `lx=en` is not answered in Japanese (A29-12).
    locale = normalized_locale(requested_context[:lx]) || I18n.locale
    render plain: I18n.t(message_key, scope: "errors.messages", locale: locale),
           content_type: "text/plain", status: :service_unavailable
  end
end
