# typed: false
# frozen_string_literal: true

module Base
  module App
    module Api
      module V0
        module Preferences
          class WebPushesController < Base::App::ApplicationController
            include ::PreferenceWebCookieEndpoint
            include ::PreferenceBrowserApi

            AUTHENTICATION_MODE = :open
            OPTIONS = %w(disabled enabled).freeze

            preference_browser_api!
            prepend_before_action :apply_default_no_store
            skip_before_action :set_preferences_cookie, unless: -> { request.get? || request.head? }, raise: false
            skip_before_action :set_current_actor, raise: false

            rescue_from PreferenceBase::ResolutionError, with: :render_preference_dependency_failure
            rescue_from PreferenceBrowserBinding::MismatchError, with: :render_binding_mismatch

            public

            def show
              render json: { web_push: readable_realm_web_push }, status: :ok
            end

            def update
              value = params[:web_push]
              unless value.is_a?(String) && OPTIONS.include?(value)
                render_preference_browser_api_invalid_fields(["/web_push"])
                return
              end

              write_preference!(
                operation: :save, actor: preference_write_actor, submitted: { web_push: value },
              )
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
