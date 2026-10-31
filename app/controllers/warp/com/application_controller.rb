# typed: false
# frozen_string_literal: true

# Anonymous Warp com surface.
#
# The corporate control-plane host keeps its public read-only pages and operational endpoints. It
# has no principal, credential, session, or OIDC relying-party boundary: sign-in, sign-out,
# callbacks, back-channel logout, and the RP cell are not part of this surface.
#
# The anonymous lifecycle is the same one Base com uses (ComAnonymousActorContext); the callbacks
# are declared here so this controller reads as the surface it owns.
module Warp
  module Com
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::Session
      include ::PreferenceGlobal
      include ::ComAnonymousActorContext
      include ::SignErrorResponses
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      layout "warp/com/application"

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception

      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure

      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "warp_com_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )
      before_action :reject_ambiguous_preference_cookies!
      before_action :set_anonymous_context
      before_action :reset_flash
      before_action :set_preferences_cookie
      before_action :hydrate_anonymous_preferences
      before_action :report_unavailable_anonymous_display_cookies
      before_action :resolve_param_context
      before_action :set_region
      before_action :apply_localization_preferences
      before_action :set_locale
      before_action :set_timezone
      before_action :set_color_theme
      before_action :set_current_observability
      prepend_around_action :with_anonymous_context_lifecycle

      ensure_fqdn_gate_first!

      private

      def set_preferences_cookie
        load_access_token_payload
      end

      def report_unavailable_anonymous_display_cookies
        return unless @preference_payload.is_a?(Hash) && @preference_payload["aud"] == "com"

        signed = @preference_payload.fetch("preferences")
        language = cookies[PreferenceIoKeys::Cookies::LANGUAGE]
        experience = cookies[PreferenceCookieName.anonymous_experience]
        return if language == signed.fetch("language") &&
          valid_anonymous_experience_cookie?(experience, signed.except("language"))

        Rails.logger.error(
          JitLogEvent.format(
            "preference.display_cookie.unavailable", surface: "warp/com", request_id: request.request_id,
          ),
        )
      end

      def preference_display_cookie_write_request?
        false
      end

      def reject_ambiguous_preference_cookies!
        names = [
          PreferenceCookieName.anonymous_jwt, PreferenceCookieName.anonymous_experience,
          PreferenceBrowserBinding::COOKIE_NAME, PreferenceIoKeys::Cookies::LANGUAGE,
        ]
        presented = request.headers["Cookie"].to_s.split(";").map { |part| part.strip.partition("=").first }
        head :bad_request if names.any? { |name| presented.count(name) > 1 }
      end
    end
  end
end
