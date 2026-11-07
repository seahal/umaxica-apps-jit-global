# typed: false
# frozen_string_literal: true

module Base
  module Org
    class SelectorsController < Base::Org::PreAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private

      def show
        response.set_header("Cache-Control", "private, no-store")
        authorize!(current_operator, to: :show?)
        BaseSelectorBootstrapAuthority.call(surface: :org, principal: current_operator)
        respond_to do |format|
          format.json do
            render json: BaseSelectorAuthority.prepare(
              surface: :org, principal: current_operator, session: selector_session,
            )
          end
          format.html do
            return redirect_to(base_org_switcher_path(ri: params[:ri]), status: :see_other) if
              selector_session&.selected_actor_context?

            result = BaseSelectorAuthority.prepare(
              surface: :org, principal: current_operator, session: selector_session,
            )
            return redirect_to(base_org_dashboard_path(ri: params[:ri]), status: :see_other) if
              result.fetch(:status).to_s == "selected"

            render_selector_page(result)
          end
        end
      end

      def update
        response.set_header("Cache-Control", "private, no-store")
        authorize!(current_operator, to: :update?)
        return reject_selected_session_update if selector_session&.selected_actor_context?

        result = BaseSelectorAuthority.select(
          surface: :org,
          principal: current_operator,
          session: selector_session,
          params: selector_params,
        )
        respond_to do |format|
          format.json { render json: result }
          format.html { redirect_to(base_org_dashboard_path(ri: params[:ri]), status: :see_other) }
        end
      rescue BaseSelectorAuthority::InvalidSelection => e
        respond_to do |format|
          format.json do
            render json: { status: "invalid_selection", error: e.message }, status: :unprocessable_content
          end
          format.html do
            result = BaseSelectorAuthority.selection_options(
              surface: :org, principal: current_operator,
            )
            render_selector_page(
              result,
              error: t("base.org.selectors.show.invalid_selection"),
              status: :unprocessable_content,
            )
          end
        end
      rescue AcmeSelectableContext::SelectionAlreadyEstablished
        reject_selected_session_update
      end

      private

      def selector_session
        rp_session = browser_rp_access_state.rp_session
        rp_session.instance_of?(RpBaseOrgSession) ? rp_session : current_session
      end

      def reject_selected_session_update
        switcher_path = base_org_switcher_path(ri: params[:ri])
        respond_to do |format|
          format.json { render json: { status: "already_selected", next: switcher_path }, status: :conflict }
          format.html { redirect_to(switcher_path, status: :see_other) }
        end
      end

      def selector_params
        # `slice` first: this reads a fixed set of keys and ignores everything else the
        # request carries (`ri`, the Turnstile token). Permitting without narrowing would
        # report those as unpermitted, which they are not - they are simply not ours.
        keys = %i(
          account_public_id organization_public_id organization_unit_public_id
          collective_public_id collective_unit_public_id
        )
        params.slice(*keys).permit(*keys).to_h.symbolize_keys
      end

      def render_selector_page(result, error: nil, status: :ok)
        candidates =
          Array(result[:accounts]).map do |candidate|
            {
              account_public_id: candidate.fetch(:public_id),
              organization_public_id: candidate.dig(:organization, :public_id),
              organization_unit_public_id: candidate.dig(:organization, :unit_public_id),
            }
          end
        render inertia: "base/org/selectors/show", props: {
          title: t("base.org.selectors.show.title"),
          description: t("base.org.selectors.show.description"),
          account_label: t("base.org.selectors.show.account_label"),
          organization_label: t("base.org.selectors.show.organization_label"),
          unit_label: t("base.org.selectors.show.unit_label"),
          submit_label: t("base.org.selectors.show.submit_label"),
          empty_message: t("base.org.selectors.show.empty_message"),
          action: base_org_selector_path(ri: params[:ri]),
          candidates:,
          error:,
        }, status:, clear_history: true
      end
    end
  end
end
