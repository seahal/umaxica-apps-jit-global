# typed: false
# frozen_string_literal: true

module Base
  module App
    # Post-login context switcher for the app surface. Selector owns the pre-access ceremony and
    # commits the first selected context; switcher only runs after that full-access gate is open,
    # shows the current account / organization / avatar, and atomically changes the current
    # context. It never creates or edits entities -- that is the accounts/organizations/avatars
    # controllers' job. Requires a selected actor context (FullAccessController).
    class SwitchersController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      public

      # R5-WU14: the context is read and switched by its owner over HTTPS (approved contract).
      def show
        result = relay_switcher(switcher_authority.switcher_context)
        return unless result

        context = result.data.deep_symbolize_keys
        respond_to do |format|
          format.json { render json: context }
          format.html { render inertia: true, props: switcher_page_props(context) }
        end
      end

      def update
        result = relay_switcher(switcher_authority.switch_context(switcher_params))
        return unless result

        if result.ok?
          respond_to do |format|
            format.json { render json: { status: "switched", next: base_app_dashboard_path(ri: params[:ri]) } }
            format.html { redirect_to(base_app_dashboard_path(ri: params[:ri]), status: :see_other) }
          end
        else
          error = result.data.to_h["error"]
          context = (switcher_authority.switcher_context.data || {}).deep_symbolize_keys
          respond_to do |format|
            format.json { render json: { status: "invalid_switch", error: }, status: :unprocessable_content }
            format.html do
              render inertia: "base/app/switchers/show", props: switcher_page_props(context, error:),
                     status: :unprocessable_content
            end
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

      def switcher_authority
        @switcher_authority ||= AvatarAuthorityClient.new(
          surface: "app",
          access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
          persona: Actor.selection.account_public_id,
        )
      end

      def relay_switcher(result)
        authorize!(result, to: :show?, with: AvatarRemoteResultPolicy)
        if result.status == :dependency
          head :service_unavailable
          return
        end

        result
      end

      def switcher_params
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
