# typed: false
# frozen_string_literal: true

module Base
  module App
    class SelectorsController < Base::App::PreAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_client, to: :show?)
        return render_selector_json if request.format.json?
        return continue_selector_sequence! if current_db_sign_in_flow_for_sequence&.sign_in_selector_pending?
        # Post-login HTML revisits belong on Switcher. Selector is the pre-access ceremony.
        return redirect_to(base_app_switcher_path(ri: params[:ri])) if current_session&.selected_actor_context?

        result = prepare_selector
        return redirect_to(base_app_dashboard_path(ri: params[:ri])) if result.fetch(:status).to_s == "selected"

        render json: result, status: :unprocessable_content
      end

      def update
        authorize!(current_client, to: :update?)
        render json: BaseSelectorAuthority.select(
          surface: :app,
          principal: current_client,
          session: current_session,
          params: selector_params,
        )
      rescue BaseSelectorAuthority::InvalidSelection => e
        render json: { status: "invalid_selection", error: e.message }, status: :unprocessable_content
      end

      private

      def render_selector_json
        render json: prepare_selector
      end

      def prepare_selector
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: current_client)
        BaseSelectorAuthority.prepare(
          surface: :app, principal: current_client,
          session: current_session,
        )
      end

      def selector_params
        # `slice` first: this reads a fixed set of keys and ignores everything else the
        # request carries (`ri`, the Turnstile token). Permitting without narrowing would
        # report those as unpermitted, which they are not - they are simply not ours.
        keys = %i(
          account_public_id organization_public_id organization_unit_public_id
          collective_public_id collective_unit_public_id avatar_public_id
        )
        params.slice(*keys).permit(*keys).to_h.symbolize_keys
      end
    end
  end
end
