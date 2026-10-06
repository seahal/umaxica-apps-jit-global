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

      def create
        authorize!(AvatarOwnershipTransfer, to: :create?)
        transfer =
          with_locked_step_up("avatar_transfer_request") do
            AvatarOwnershipTransfers::RequestOperation.call(
              actor: current_client,
              surface: "app",
              subject_public_id: Actor.selection.account_public_id,
              avatar_public_id: Actor.selection.avatar_public_id,
              target_surface: transfer_params.fetch(:target_surface, ""),
              target_collective_public_id: transfer_params.fetch(:target_collective_public_id, ""),
            )
          end
        return if performed?

        render_transfer(transfer)
      rescue AvatarOwnershipTransfers::Unauthorized
        head :forbidden
      rescue AvatarOwnershipTransfers::InvalidTransfer => e
        render plain: e.message, status: :unprocessable_content
      end

      def accept
        transfer = find_transfer!
        authorize!(transfer, to: :accept?)
        accepted =
          with_locked_step_up("avatar_transfer_accept") do
            AvatarOwnershipTransfers::AcceptOperation.call(
              actor: current_client,
              surface: "app",
              subject_public_id: Actor.selection.account_public_id,
              transfer_public_id: transfer.public_id,
            )
          end
        return if performed?

        render_transfer(accepted)
      rescue AvatarOwnershipTransfers::Unauthorized
        head :forbidden
      rescue AvatarOwnershipTransfers::Expired => e
        render plain: e.message, status: :gone
      rescue AvatarOwnershipTransfers::InvalidTransfer => e
        render plain: e.message, status: :unprocessable_content
      end

      def cancel
        transfer = find_transfer!
        authorize!(transfer, to: :cancel?)
        cancelled =
          with_locked_step_up("avatar_transfer_cancel") do
            AvatarOwnershipTransfers::CancelOperation.call(
              actor: current_client,
              surface: "app",
              subject_public_id: Actor.selection.account_public_id,
              transfer_public_id: transfer.public_id,
            )
          end
        return if performed?

        render_transfer(cancelled)
      rescue AvatarOwnershipTransfers::Unauthorized
        head :forbidden
      rescue AvatarOwnershipTransfers::Expired => e
        render plain: e.message, status: :gone
      rescue AvatarOwnershipTransfers::InvalidTransfer => e
        render plain: e.message, status: :unprocessable_content
      end

      private

      def with_locked_step_up(scope)
        token = current_session_token ||
          raise(AvatarOwnershipTransfers::Unauthorized, "Step-Up session token missing")
        result = nil
        token.with_lock do
          requirement = step_up_requirement(scope: scope)
          if StepUpResolver.call(token: token, requirement: requirement).satisfied?
            result = yield
          else
            require_step_up!(scope: scope)
          end
        end
        result
      end

      def find_transfer!
        AvatarOwnershipTransfer.find_by(public_id: params.expect(:id)) || raise(ActiveRecord::RecordNotFound)
      end

      def transfer_params
        keys = %i(target_surface target_collective_public_id)
        params.slice(*keys).permit(*keys).to_h.symbolize_keys
      end

      def render_transfer(transfer)
        body = { status: transfer.state, transfer_public_id: transfer.public_id }
        respond_to do |format|
          format.json { render json: body }
          format.html { redirect_to(base_app_dashboard_path(ri: params[:ri]), status: :see_other) }
        end
      end
    end
  end
end
