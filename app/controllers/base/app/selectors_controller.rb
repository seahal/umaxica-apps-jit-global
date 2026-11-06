# typed: false
# frozen_string_literal: true

module Base
  module App
    class SelectorsController < Base::App::PreAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        response.set_header("Cache-Control", "private, no-store")
        authorize!(current_client, to: :show?)
        return render_selector_json if request.format.json?
        # Post-login HTML revisits belong on Switcher. Selector is the pre-access ceremony.
        return redirect_to(base_app_switcher_path(ri: params[:ri])) if selector_session&.selected_actor_context?

        result = prepare_selector
        return redirect_to(base_app_dashboard_path(ri: params[:ri])) if result.fetch(:status).to_s == "selected"

        render_selector_page(result)
      end

      def update
        response.set_header("Cache-Control", "private, no-store")
        authorize!(current_client, to: :update?)
        return redirect_selected_session_to_switcher if selector_session&.selected_actor_context?

        result = BaseSelectorAuthority.select(
          surface: :app,
          principal: current_client,
          session: selector_session,
          params: selector_params,
        )
        respond_to do |format|
          format.json { render json: result }
          format.html { redirect_to(base_app_dashboard_path(ri: params[:ri]), status: :see_other) }
        end
      rescue BaseSelectorAuthority::InvalidSelection => e
        respond_to do |format|
          format.json do
            render json: { status: "invalid_selection", error: e.message }, status: :unprocessable_content
          end
          format.html do
            result = prepare_selector
            render_selector_page(
              result,
              error: t("base.app.selectors.show.invalid_selection"),
              status: :unprocessable_content,
            )
          end
        end
      rescue AcmeSelectableContext::SelectionAlreadyEstablished
        redirect_selected_session_to_switcher
      end

      private

      def redirect_selected_session_to_switcher
        switcher_path = base_app_switcher_path(ri: params[:ri])
        respond_to do |format|
          format.json do
            render json: { status: "already_selected", next: switcher_path }, status: :conflict
          end
          format.html { redirect_to(switcher_path, status: :see_other) }
        end
      end

      def render_selector_json
        render json: prepare_selector
      end

      def prepare_selector
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: current_client)
        BaseSelectorAuthority.prepare(
          surface: :app, principal: current_client,
          session: selector_session,
        )
      end

      def selector_session
        rp_session = browser_rp_access_state.rp_session
        rp_session.instance_of?(RpBaseAppSession) ? rp_session : current_session
      end

      def render_selector_page(result, error: nil, status: :ok)
        candidates =
          Array(result[:accounts]).map do |candidate|
            {
              account_public_id: candidate.fetch(:public_id),
              organization_public_id: candidate.dig(:organization, :public_id),
              organization_unit_public_id: candidate.dig(:organization, :unit_public_id),
              avatar_public_id: candidate.dig(:avatar, :public_id),
            }
          end
        render inertia: "base/app/selectors/show", props: {
          title: t("base.app.selectors.show.title"),
          description: t("base.app.selectors.show.description"),
          account_label: t("base.app.selectors.show.account_label"),
          organization_label: t("base.app.selectors.show.organization_label"),
          unit_label: t("base.app.selectors.show.unit_label"),
          avatar_label: t("base.app.selectors.show.avatar_label"),
          submit_label: t("base.app.selectors.show.submit_label"),
          empty_message: t("base.app.selectors.show.empty_message"),
          action: base_app_selector_path(ri: params[:ri]),
          candidates: candidates,
          error: error,
          up_link: nil,
        }, status: status, clear_history: true
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
