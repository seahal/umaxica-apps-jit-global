# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module Up
        class BaseController < ::Auth::Org::ApplicationController
          include ::RateLimit

          include ActionPolicy::Controller

          # Note: AuthenticationOperator is NOT included here for unauthenticated sign-up
          include ::PreferenceGlobal

          include ::PreferenceAdoption

          include ::ActorSupport

          include ::Finisher

          AUTHENTICATION_MODE = :guest

          allow_browser versions: :modern

          before_action :set_current_context
          before_action :set_preferences_cookie
          before_action :resolve_param_context
          before_action :set_region
          before_action :set_current
          before_action :apply_localization_preferences
          before_action :set_locale
          before_action :set_timezone
          before_action :set_color_theme
          append_after_action :finish_request

          protect_from_forgery using: :header_or_legacy_token,
                               trusted_origins: JitHostOriginEnv.trusted_origins(
                                 ENV.fetch("PRIVATE_AUTH_STAFF_URL"),
                               ),
                               with: :exception

          private

          def after_login_path
            session.delete(:auth_ceremony_admitted_intent)
            base_org_identity_url(ri: current_region_identifier, host: base_authority_host)
          end
        end
      end
    end
  end
end
