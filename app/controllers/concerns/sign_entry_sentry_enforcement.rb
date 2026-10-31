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
    return if flow == "sign_in" && auth_ceremony_surface == "org" && self.class.sign_entry_standby_only? &&
      SignEntryClassification::STANDBY_ONLY_CONTROLLERS.include?(self.class.name)

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
    # D-59: the static declaration is the only classification source. An undeclared reachable
    # action fails loudly instead of being guessed from its path or silently treated as excluded;
    # the static guard keeps the reachable set equal to the declared set.
    classification = resolved_sign_entry_classification
    if classification.nil?
      raise SignEntryClassification::UndeclaredClassificationError,
            "#{self.class.name}##{action_name} reached the Sign Entry Sentry without a declaration"
    end
    return nil if classification == :excluded
    return sign_entry_intent_from_verified_parent if classification == :parent_intent

    classification.to_s
  end

  # The parent_intent classification resolves its flow from the verified parent only: an admitted
  # ceremony's persisted intent. Request parameters never decide it (two.md section 3.5).
  def sign_entry_intent_from_verified_parent
    return "sign_up" if auth_ceremony_matches_intent?("sign_up")
    return "sign_in" if auth_ceremony_matches_intent?("sign_in")

    nil
  end

  def sign_entry_sentry_flow_for_binding(binding)
    if AuthAdmissionBinding::PARENT_PURPOSES.fetch(:authorization_transaction).include?(binding.purpose)
      transaction_record =
        case auth_ceremony_surface
        when "app"
          OpBaseAppRecord.connected_to(role: :writing) do
            ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
          end
        when "org"
          OpBaseOrgRecord.connected_to(role: :writing) do
            OperatorOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
          end
        else raise ArgumentError, "unsupported Auth ceremony surface"
        end
      return AuthEntryIntentResolver.call(
        prompt: transaction_record.oidc_prompt,
        entry_intent: binding.entry_intent,
      )
    end

    raise ArgumentError, "unsupported Sign Entry Sentry binding purpose"
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
