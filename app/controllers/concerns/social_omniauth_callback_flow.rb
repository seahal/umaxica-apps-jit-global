# typed: false
# frozen_string_literal: true

# Shared outer flow for OmniAuth callback controllers.
#
# The callback meaning remains surface-owned:
# - app delegates successful callbacks to operation-specific external authentication use cases.
# - org resolves an existing Operator by staff email.
module SocialOmniauthCallbackFlow
  extend ActiveSupport::Concern

  def omniauth
    auth = request.env["omniauth.auth"] || test_mode_omniauth_auth_hash
    Rails.logger.debug(
      JitLogEvent.format(
        social_omniauth_callback_received_event,
        **social_omniauth_callback_received_payload(auth),
      ),
    )

    return redirect_missing_auth_hash unless auth

    run_social_omniauth_callback(auth)
  rescue SocialAuth::BaseError => e
    handle_social_auth_error(e)
  rescue StandardError
    clear_social_auth_intent!
    raise
  end

  private

  def verified_request?
    super || (action_name == "omniauth" && verified_social_callback_request?)
  end

  def handle_unverified_request
    if action_name == "omniauth"
      # Every failing guard branch records its reason; when none was recorded the request is
      # still unverified, so it is rejected with the guard's own default rather than allowed.
      rejection = request.env["social_callback_guard.rejection"] || {
        reason: "csrf_unverified",
        provider: params[:provider].to_s,
        details: {},
      }
      reject_social_callback!(**rejection)
    else
      super
    end
  end

  def run_social_omniauth_callback(auth)
    if social_omniauth_callback_requires_writing_role?
      ActiveRecord::Base.connected_to(role: :writing) { handle_omniauth_callback(auth) }
    else
      handle_omniauth_callback(auth)
    end
  end

  def redirect_missing_auth_hash
    Rails.logger.error(JitLogEvent.format(social_omniauth_missing_auth_event))
    redirect_to(
      social_auth_failure_redirect_path,
      alert: I18n.t(social_omniauth_failure_i18n_key),
    )
  end

  def handle_missing_auth
    redirect_missing_auth_hash
  end

  def handle_unexpected_error(error, auth)
    clear_social_auth_intent!
    Rails.logger.error(
      JitLogEvent.format(
        social_omniauth_unexpected_error_event,
        error_class: error.class.name,
        error_message: error.message,
        provider: auth&.provider,
        exception: error,
      ),
    )
    raise error
  end

  def social_omniauth_callback_requires_writing_role?
    false
  end

  def test_mode_omniauth_auth_hash
    return nil unless defined?(OmniAuth) && OmniAuth.config.test_mode

    provider = params[:provider].to_s
    auth_hash = OmniAuth.config.mock_auth[provider.to_sym]
    request.env["omniauth.auth"] = auth_hash if auth_hash.present?
    auth_hash
  end

  def social_omniauth_callback_received_event
    "sign.social.omniauth.callback_received"
  end

  def social_omniauth_callback_received_payload(auth)
    {
      provider: auth&.provider,
    }
  end

  def social_omniauth_missing_auth_event
    "sign.social.omniauth.missing_auth_hash"
  end

  def social_omniauth_unexpected_error_event
    "sign.social.omniauth.unexpected_error"
  end

  def social_omniauth_failure_i18n_key
    "sign.app.social.sessions.create.failure"
  end
end
