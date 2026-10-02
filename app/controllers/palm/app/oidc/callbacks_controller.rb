# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Oidc
      class CallbacksController < Palm::App::BareController
        include ::JumpRtReturnVerification

        AUTHENTICATION_MODE = :bare

        before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
        after_action :set_callback_cache_headers

        def show
          return render_callback_stub if params[:code].blank? && params[:error].blank? && params[:state].blank?

          flows = pending_flows
          flow = flows[params[:state].to_s]
          return invalid_request unless valid_native_return?(flow)

          completion = OidcClientStoresStaticClientStore::NATIVE_COMPLETION_URIS.fetch(flow.fetch("client_id"))
          flows.delete(params[:state].to_s)
          if flows.empty?
            session.delete(::Palm::App::Sign::EntriesController::PENDING_FLOWS_SESSION_KEY)
          else
            session[::Palm::App::Sign::EntriesController::PENDING_FLOWS_SESSION_KEY] = flows
          end
          uri = URI.parse(completion)
          uri.query = flow.fetch("verified_return").to_query
          response.set_header("Referrer-Policy", "no-referrer")
          redirect_to(uri.to_s, allow_other_host: true, status: :see_other)
        end

        private

        def redirect_to_jump_return_target!(return_url)
          flows = pending_flows
          flow = flows[params[:state].to_s]
          return invalid_request unless flow && flow_active?(flow)

          values = params.slice(:code, :state, :error, :error_description).permit(
            :code, :state, :error,
            :error_description,
          ).to_h
          return invalid_request unless values["code"].present? ^ values["error"].present?

          flow["verified_return"] = values
          session[::Palm::App::Sign::EntriesController::PENDING_FLOWS_SESSION_KEY] = flows
          super
        end

        def valid_native_return?(flow)
          flow && flow_active?(flow) && flow["verified_return"].present? &&
            flow["verified_return"] == params.slice(:code, :state, :error, :error_description).permit(
              :code, :state,
              :error, :error_description,
            ).to_h
        end

        def flow_active?(flow)
          created_at = flow.fetch("created_at")
          created_at <= Time.current.to_i &&
            Time.current.to_i < created_at + ::Palm::App::Sign::EntriesController::FLOW_TTL.to_i
        end

        def pending_flows
          key = ::Palm::App::Sign::EntriesController::PENDING_FLOWS_SESSION_KEY
          flows = session[key].to_h.select { |_state, flow| flow_active?(flow) }
          if flows.empty?
            session.delete(key)
          else
            session[key] = flows
          end
          flows
        end

        def invalid_request
          render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
        end

        def render_callback_stub
          render(
            # rubocop:disable I18n/RailsI18n/DecorateString
            plain: "This URL is reserved for completing app authentication.\n" \
                   "Open the mobile app and try signing in again.",
            # rubocop:enable I18n/RailsI18n/DecorateString
            status: :ok,
          )
        end

        def set_callback_cache_headers
          response.headers["Cache-Control"] = "no-store"
        end
      end
    end
  end
end
