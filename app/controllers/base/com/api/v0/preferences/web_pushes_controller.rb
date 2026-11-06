# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Api
      module V0
        module Preferences
          class WebPushesController < Base::Com::ApplicationController
            include ::PreferenceWebCookieEndpoint
            include ::PreferenceBrowserApi

            AUTHENTICATION_MODE = :open
            OPTIONS = {
              "disabled" => ComPreferenceWebPushOption::DISABLED,
              "enabled" => ComPreferenceWebPushOption::ENABLED,
            }.freeze

            preference_browser_api!
            prepend_before_action :apply_default_no_store
            skip_before_action :set_preferences_cookie

            rescue_from PreferenceBase::ResolutionError, with: :render_preference_dependency_failure
            rescue_from PreferenceBrowserBinding::MismatchError, with: :render_binding_mismatch

            public

            def show
              render json: { web_push: readable_com_web_push }, status: :ok
            end

            def update
              value = params[:web_push]
              unless value.is_a?(String) && OPTIONS.key?(value)
                render_preference_browser_api_invalid_fields(["/web_push"])
                return
              end

              raw_binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
              issuance =
                write_preference!(
                  operation: :save, actor: Actor.current,
                  submitted: { web_push: value },
                ) do |preference, _time, submitted|
                  unless PreferenceBrowserBinding.valid_value?(raw_binding)
                    raw_binding = PreferenceBrowserBinding.mint_value
                  end
                  cookie = load_or_create_preference_cookie!(preference)
                  require_matching_existing_browser_binding!(cookie, raw_binding)
                  store_com_browser_binding!(preference.id, raw_binding)
                  ComPreferenceWebPushOption.ensure_defaults!
                  push = ComPreferenceWebPush.find_or_initialize_by(preference_id: preference.id)
                  push.update!(option_id: OPTIONS.fetch(submitted.fetch(:web_push)))
                end
              write_browser_binding_cookie(raw_binding, expires_at: issuance.expires_at)
              render json: { web_push: value }, status: :ok
            end

            private

            def render_preference_dependency_failure
              render_problem(:service_unavailable)
            end

            def render_binding_mismatch
              render_problem(:authorization_denied)
            end
          end
        end
      end
    end
  end
end
