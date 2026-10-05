# typed: false
# frozen_string_literal: true

module Base
  module Com
    # Switches the authenticated Visitor's server-validated Individual and Company context.
    # The com surface has no Avatar capability; the shared resolver returns only nil Avatar slots.
    class SwitchersController < Base::Com::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_visitor, to: :show?)
        context = current_context

        respond_to do |format|
          format.json { render json: context }
          format.html { render inertia: true, props: switcher_page_props(context) }
        end
      end

      def update
        authorize!(current_visitor, to: :update?)
        BaseSwitcherAuthority.switch(
          surface: :com,
          principal: current_visitor,
          session: current_session,
          params: switcher_params,
        )

        respond_to do |format|
          format.json { render json: { status: "switched", next: base_com_dashboard_path(ri: params[:ri]) } }
          format.html { redirect_to(base_com_dashboard_path(ri: params[:ri]), status: :see_other) }
        end
      rescue BaseSwitcherAuthority::InvalidSwitch => e
        context = current_context

        respond_to do |format|
          format.json do
            render json: { status: "invalid_switch", error: e.message }, status: :unprocessable_content
          end
          format.html do
            render inertia: "base/com/switchers/show",
                   props: switcher_page_props(context, error: e.message),
                   status: :unprocessable_content
          end
        end
      end

      private

      def switcher_page_props(context, error: nil)
        current = context[:current]

        {
          title: "Switcher",
          up_link: dashboard_up_link,
          current: current && {
            account_public_id: current[:account_public_id],
            organization_public_id: current[:organization_public_id],
            organization_unit_public_id: current[:organization_unit_public_id],
            avatar_public_id: current[:avatar_public_id],
          },
          candidates: Array(context[:candidates]).map { |candidate| serialize_candidate(candidate) },
          error: error,
        }
      end

      def serialize_candidate(candidate)
        {
          account_public_id: candidate[:public_id],
          organization_public_id: candidate.dig(:organization, :public_id),
          avatar_public_id: candidate.dig(:avatar, :public_id),
        }
      end

      def current_context
        BaseSwitcherAuthority.current(
          surface: :com,
          principal: current_visitor,
          session: current_session,
        )
      end

      def switcher_params
        keys = %i(
          account_public_id organization_public_id organization_unit_public_id
          collective_public_id collective_unit_public_id avatar_public_id
        )
        params.slice(*keys).permit(*keys).to_h.symbolize_keys
      end
    end
  end
end
