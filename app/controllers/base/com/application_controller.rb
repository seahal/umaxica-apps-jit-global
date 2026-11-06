# typed: false
# frozen_string_literal: true

# Anonymous Base com surface.
#
# The com realm has no principal, credential, session, or admission boundary: it renders the
# public preference entry and operational endpoints for anyone who reaches the corporate host.
# This controller therefore owns only the anonymous request lifecycle:
#
#   host/rate/no-store -> CSRF/Origin -> anonymous actor context -> preference transport ->
#   localization/theme -> action
#
# It deliberately does not include ActorSupport, BrowserRpAuthentication, or
# the withdrawal/verification/session-limit/authorization callbacks: each of those reads or
# resolves a principal, and a com request must never read another surface's credential, session,
# or actor. The anonymous context is installed explicitly and cleared when the request ends, so
# localization, theme, and URL overlay keep working without leaving actor state on the thread.
module Base
  module Com
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore

      include ::Session
      include ::PreferenceGlobal
      include ::ComAnonymousActorContext
      include ::BasePreferenceActorProjection

      include ::SignErrorResponses
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      layout "base/com/application"

      allow_browser versions: :modern

      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure

      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "base_com_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )
      before_action :reject_ambiguous_preference_cookies!
      before_action :set_anonymous_context
      before_action :reset_flash
      before_action :set_preferences_cookie
      before_action :hydrate_anonymous_preferences
      before_action :repair_anonymous_display_cookies
      before_action :hydrate_base_preference_actor_state
      before_action :resolve_param_context
      before_action :set_region
      before_action :apply_localization_preferences
      before_action :set_locale
      before_action :set_timezone
      before_action :set_color_theme
      before_action :set_current_observability
      prepend_around_action :with_anonymous_context_lifecycle

      # Rails validates Origin and Fetch Metadata first; require its session-bound token before
      # surface callbacks. This is the only write protection the anonymous surface has, so it
      # stays ahead of every action.
      prepend_before_action :require_authenticity_token_for_unsafe_request!
      protect_from_forgery using: :header_or_legacy_token, with: :exception, prepend: true
      ensure_fqdn_gate_first!
      prepend_before_action :apply_default_no_store

      private

      def set_preferences_cookie
        super if request.get? || request.head?
      end

      def cookie_context
        context = super
        region = anonymous_com_actor_region
        region ? context.merge(ri: region) : context
      end

      def anonymous_com_actor_region
        return @anonymous_com_actor_region if defined?(@anonymous_com_actor_region)
        return unless (request.get? || request.head?) && @preference_payload.is_a?(Hash)

        @anonymous_com_actor_region =
          with_preference_connection(:writing) do
            ComPreference.transaction do
              preference = ComPreference.lock.find_by(
                public_id: @preference_payload.fetch("sub"), status_id: ComPreferenceStatus::ACTIVE,
              )
              now = ComPreference.database_now
              next unless preference&.issuance_active_at?(now: now) && now.to_i < @preference_payload.fetch("exp")

              region = ComPreferenceRegion.find_by(preference_id: preference.id)
              next unless region

              case region.option_id
              when ComPreferenceRegionOption::JP then "jp"
              when ComPreferenceRegionOption::US then "us"
              else raise PreferenceBase::ResolutionError, "unknown com preference region"
              end
            end
          end
      rescue ActiveRecord::ActiveRecordError, PreferenceBase::ResolutionError => e
        Rails.logger.error(JitLogEvent.format("preference.actor_region.read_failed", error_class: e.class.name))
        @anonymous_com_actor_region = nil
      end

      def repair_anonymous_display_cookies
        return unless request.get? || request.head?
        return unless @preference_payload.is_a?(Hash) && @preferences.is_a?(ComPreference)

        signed = @preference_payload.fetch("preferences")
        language = cookies[PreferenceIoKeys::Cookies::LANGUAGE]
        experience = cookies[PreferenceCookieName.anonymous_experience]
        return if language == signed["language"] &&
          valid_anonymous_experience_cookie?(experience, signed.except("language"))

        log_invalid_display_cookies(language, experience, signed)

        snapshot = nil
        expires_at = Time.at(@preference_payload.fetch("exp")).utc
        with_preference_connection(:writing) do
          @preferences.with_lock do
            now = ComPreference.database_now
            next unless @preferences.issuance_active_at?(now: now)
            next unless now < expires_at

            snapshot = build_preferences_payload(@preferences)
            raise PreferenceBase::ResolutionError, "invalid display preference snapshot" unless
              SecurityJwtPreferenceTokenCodec.valid_display_snapshot?(snapshot)
          end
        end
        return unless snapshot

        cookies[PreferenceIoKeys::Cookies::LANGUAGE] =
          anonymous_com_cookie_options(expires_at: expires_at, httponly: false).merge(value: snapshot.fetch("language"))
        cookies[PreferenceCookieName.anonymous_experience] =
          anonymous_com_cookie_options(expires_at: expires_at, httponly: false)
            .merge(value: snapshot.except("language").to_json)
      rescue ActiveRecord::ActiveRecordError, PreferenceBase::ResolutionError => e
        handle_display_repair_failure(e)
      end

      def log_invalid_display_cookies(language, experience, signed)
        invalid_language = language.present? &&
          !SecurityJwtPreferenceTokenCodec.valid_display_snapshot?(signed.merge("language" => language))
        invalid_experience = experience.present? &&
          !valid_anonymous_experience_shape?(experience, signed.fetch("language"))
        return unless invalid_language || invalid_experience

        Rails.logger.error(JitLogEvent.format("preference.display_cookie.invalid", request_id: request.request_id))
      end

      def valid_anonymous_experience_shape?(value, language)
        return false unless value.is_a?(String)
        return false if value.bytesize > SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_MAX_BYTES

        parsed = JSON.parse(value, allow_duplicate_key: false)
        return false unless parsed.is_a?(Hash) && !parsed.key?("language")

        SecurityJwtPreferenceTokenCodec.valid_display_snapshot?(parsed.merge("language" => language))
      rescue JSON::ParserError
        false
      end

      def handle_display_repair_failure(error)
        Rails.logger.error(JitLogEvent.format("preference.display_repair.failed", error_class: error.class.name))
        detach_preference_credential!
      end

      def reject_ambiguous_preference_cookies!
        names = [
          PreferenceCookieName.anonymous_jwt, PreferenceCookieName.anonymous_experience,
          PreferenceBrowserBinding::COOKIE_NAME, PreferenceIoKeys::Cookies::LANGUAGE,
        ]
        cookie_header = request.headers["Cookie"].to_s
        presented = cookie_header.split(";").map { |part| part.strip.partition("=").first }
        head :bad_request if names.any? { |name| presented.count(name) > 1 }
      end

      # Com display cookies are issued only by the explicit preference write boundary.
      def preference_display_cookie_write_request?
        false
      end

      def require_authenticity_token_for_unsafe_request!
        return unless protect_against_forgery?
        return if request.get? || request.head? || verified_query_request?
        return if any_authenticity_token_valid?

        instrument_unverified_request
        handle_unverified_request
      end
    end
  end
end
