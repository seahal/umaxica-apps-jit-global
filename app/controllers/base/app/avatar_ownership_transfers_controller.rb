# typed: false
# frozen_string_literal: true

module Base
  module App
    class AvatarOwnershipTransfersController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      step_up only: :create, scope: "avatar_transfer_request"
      step_up only: :accept, scope: "avatar_transfer_accept"
      step_up only: :cancel, scope: "avatar_transfer_cancel"

      public

      # R5-WU14: the Avatar owner re-checks Step-Up under its root lock and runs the transfer
      # Operations; this Base Self-RP only relays and, when asked, starts the Step-Up ceremony.
      def create
        relay_transfer(
          avatar_authority.request_transfer(
            transfer_params,
            idempotency_key: request.get_header("HTTP_IDEMPOTENCY_KEY"),
          ),
        )
      end

      def accept
        relay_transfer(avatar_authority.accept_transfer(params.expect(:id), transfer_kind: params[:transfer_kind].to_s))
      end

      def cancel
        relay_transfer(avatar_authority.cancel_transfer(params.expect(:id), transfer_kind: params[:transfer_kind].to_s))
      end

      private

      def avatar_authority
        AvatarAuthorityClient.new(
          surface: "app",
          access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
          persona: Actor.selection.account_public_id,
        )
      end

      def relay_transfer(result)
        error = result.data.to_h["error"]
        if result.status == :forbidden && %w(owner_denied step_up_required).include?(error)
          authorize!(result, to: :relay?, with: AvatarRemoteResultPolicy)
          return require_step_up!(scope: result.data.fetch("scope")) if error == "step_up_required"

          return head(:forbidden)
        end
        authorize!(result, to: :show?, with: AvatarRemoteResultPolicy)
        raise ActiveRecord::RecordNotFound, "transfer not found" if result.status == :not_found
        return render(plain: result.data["message"].to_s, status: :gone) if result.status == :gone
        return render(
          plain: result.data["message"].to_s,
          status: :unprocessable_content,
        ) if result.status == :unprocessable
        return head(:service_unavailable) unless result.ok?

        respond_to do |format|
          format.json { render json: result.data }
          format.html { redirect_to(base_app_dashboard_path(ri: params[:ri]), status: :see_other) }
        end
      end

      def transfer_params
        keys = %i(target_surface target_collective_public_id)
        params.slice(*keys).permit(*keys).to_h.symbolize_keys
      end
    end
  end
end
