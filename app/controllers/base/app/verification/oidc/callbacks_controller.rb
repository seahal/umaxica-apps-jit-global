# typed: false
# frozen_string_literal: true

module Base
  module App
    module Verification
      module Oidc
        class CallbacksController < Base::App::ApplicationController
          include StepUpCeremonyLogging

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          public

          def show
            response.set_header("Cache-Control", "private, no-store")
            response.set_header("Referrer-Policy", "no-referrer")
            authorize!(current_client, to: :show?)
            result = RpStepUpCallbackDispatcher.call(
              cell: RpCellBinding.for_client(oidc_client_id),
              access_state: browser_rp_access_state,
              actor: current_client,
              browser_binding: base_admission_browser_nonce,
              state_token: params[:state],
              issuer: params[:iss],
              code: params[:code],
              error: params[:error],
            )
            render_result(result)
          rescue ActiveRecord::ActiveRecordError => e
            log_callback_refusal("persistence_unavailable", outcome: "unavailable", error_class: e.class.name)
            render plain: t("sign.app.verification.step_up_unavailable"), status: :service_unavailable
          end

          private

          def browser_rp_safe_request_refresh_enabled? = false

          def render_result(result)
            case result.outcome
            when :installed
              install_browser_rp_token_response!(result.token_response)
              redirect_to(result.return_target, status: :see_other, allow_other_host: false)
            when :cancelled, :refused, :indeterminate, :conflict, :stale
              log_callback_refusal(result.reason_code, outcome: result.outcome.to_s)
              render plain: t("sign.app.verification.step_up_refused"), status: :conflict
            when :unavailable
              log_callback_refusal(result.reason_code, outcome: result.outcome.to_s)
              render plain: t("sign.app.verification.step_up_unavailable"), status: :service_unavailable
            when :invalid
              log_callback_refusal(result.reason_code, outcome: result.outcome.to_s)
              render plain: t("errors.messages.invalid_request"), status: :bad_request
            else
              raise ArgumentError, "unsupported RP step-up callback outcome: #{result.outcome.inspect}"
            end
          end

          def log_callback_refusal(reason_code, outcome:, error_class: nil)
            log_step_up_ceremony(
              "refused", outcome:, reason_code:, error_class:, stage: "rp_callback",
            )
          end
        end
      end
    end
  end
end
