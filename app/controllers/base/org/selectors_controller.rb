# typed: false
# frozen_string_literal: true

module Base
  module Org
    class SelectorsController < Base::Org::PreAccessController
      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private

      def show
        response.set_header("Cache-Control", "private, no-store")
        authorize!(current_operator, to: :show?)
        BaseSelectorBootstrapAuthority.call(surface: :org, principal: current_operator)
        result = BaseSelectorAuthority.prepare(surface: :org, principal: current_operator, session: selector_session)
        respond_to do |format|
          format.json { render json: result }
          format.html do
            return redirect_to(base_org_dashboard_path(ri: params[:ri]), status: :see_other) if
              result.fetch(:status).to_s == "selected"

            render plain: I18n.t("auth.rp_feature_unavailable"), status: :not_acceptable
          end
        end
      end

      def update
        response.set_header("Cache-Control", "private, no-store")
        authorize!(current_operator, to: :update?)
        return reject_selected_session_update if selector_session&.selected_actor_context?

        render json: BaseSelectorAuthority.select(
          surface: :org,
          principal: current_operator,
          session: selector_session,
          params: selector_params,
        )
      rescue BaseSelectorAuthority::InvalidSelection => e
        render json: { status: "invalid_selection", error: e.message }, status: :unprocessable_content
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
    end
  end
end
