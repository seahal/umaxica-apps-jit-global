# typed: false
# frozen_string_literal: true

module Base
  module App
    module Edge
      module V0
        class CookiesController < Base::App::ApplicationController
          include ::PreferenceWebCookieEndpoint

          AUTHENTICATION_MODE = :open

          skip_before_action :set_preferences_cookie, raise: false
          skip_before_action :resolve_param_context, raise: false
          skip_before_action :set_region, raise: false

          skip_before_action :set_color_theme, raise: false
          skip_before_action :enforce_withdrawal_gate!
          skip_before_action :transparent_refresh_access_token
          skip_before_action :enforce_verification_if_required

          def show
            issue_preference_dbsc_registration_header_for(current_preference_record_for_dbsc)
            render json: { show_banner: show_banner?, dbsc: preference_dbsc_payload }, status: :ok
          end

          def update
            apply_consented_update_from_request!
            set_consented_buffer_cookie!
            issue_preference_dbsc_registration_header_for(current_preference_record_for_dbsc)
            render json: { show_banner: show_banner?, dbsc: preference_dbsc_payload }, status: :ok
          end

          private

          def current_preference_record_for_dbsc
            # A refused credential deletes its cookie from the jar, so a second lookup in the same
            # request would see no cookie and create a replacement row on this GET. The refusal holds
            # for the whole request.
            return if preference_refresh_failed?

            preference, = load_preference_record_from_refresh_token!(create_if_missing: true)
            preference
          end

          def preference_dbsc_payload
            preference_dbsc_payload_for(current_preference_record_for_dbsc)
          end
        end
      end
    end
  end
end
