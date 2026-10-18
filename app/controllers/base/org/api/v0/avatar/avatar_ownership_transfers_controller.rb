# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Avatar
          # Avatar ownership transfer owner endpoint for the org Base Self-RP (R5-WU14). Step-Up is
          # verified here under the root lock; the existing transfer Operations decide and write.
          class AvatarOwnershipTransfersController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "org"

            authorize :user, through: :avatar_actor
            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            before_action :verify_avatar_persona!
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, with: :render_bad_request

            public

            def create
              authorize!(::AvatarOwnershipTransfer, to: :create?)
              ensure_registry_admission_available! if registry_request?
              transfer =
                with_owner_step_up("avatar_transfer_request") do
                  if registry_request?
                    AvatarOwnershipTransfers::RegistryRequestOperation.call(
                      actor: avatar_actor,
                      surface: "org",
                      subject_public_id: Actor.selection.account_public_id,
                      avatar_public_id: Actor.selection.avatar_public_id,
                      target_surface: transfer_params.fetch(:target_surface, ""),
                      target_collective_public_id: transfer_params.fetch(:target_collective_public_id, ""),
                      idempotency_key: idempotency_key,
                      request_fingerprint: registry_request_fingerprint,
                    )
                  else
                    AvatarOwnershipTransfers::RequestOperation.call(
                      actor: avatar_actor,
                      surface: "org",
                      subject_public_id: Actor.selection.account_public_id,
                      avatar_public_id: Actor.selection.avatar_public_id,
                      target_surface: transfer_params.fetch(:target_surface, ""),
                      target_collective_public_id: transfer_params.fetch(:target_collective_public_id, ""),
                    )
                  end
                end
              return if performed?

              render_transfer(transfer, transfer_kind: (registry_request? ? "registry" : nil))
            rescue AvatarOwnershipTransfers::Unauthorized
              render_owner_denied
            rescue AvatarOwnershipTransfers::InvalidTransfer => e
              render json: { error: "invalid_transfer", message: e.message }, status: :unprocessable_content
            end

            def accept
              transfer = registry_transfer? ? find_registry_reservation! : find_transfer!
              authorize!(transfer, to: :accept?, with: AvatarTransferReservationPolicy) if registry_transfer?
              authorize!(transfer, to: :accept?) unless registry_transfer?
              ensure_registry_admission_available! if registry_transfer?
              accepted =
                with_owner_step_up("avatar_transfer_accept") do
                  if registry_transfer?
                    AvatarOwnershipTransfers::RegistryAcceptOperation.call(
                      actor: avatar_actor,
                      surface: "org",
                      subject_public_id: Actor.selection.account_public_id,
                      reservation_public_id: params.expect(:ref),
                    )
                  else
                    AvatarOwnershipTransfers::AcceptOperation.call(
                      actor: avatar_actor,
                      surface: "org",
                      subject_public_id: Actor.selection.account_public_id,
                      transfer_public_id: transfer.public_id,
                    )
                  end
                end
              return if performed?

              render_transfer(accepted, transfer_kind: (registry_transfer? ? "registry" : nil))
            rescue AvatarOwnershipTransfers::Unauthorized
              render_owner_denied
            rescue AvatarOwnershipTransfers::Expired => e
              render json: { error: "expired", message: e.message }, status: :gone
            rescue AvatarOwnershipTransfers::InvalidTransfer => e
              render json: { error: "invalid_transfer", message: e.message }, status: :unprocessable_content
            end

            def cancel
              transfer = registry_transfer? ? find_registry_reservation! : find_transfer!
              authorize!(transfer, to: :cancel?, with: AvatarTransferReservationPolicy) if registry_transfer?
              authorize!(transfer, to: :cancel?) unless registry_transfer?
              ensure_registry_admission_available! if registry_transfer?
              cancelled =
                with_owner_step_up("avatar_transfer_cancel") do
                  if registry_transfer?
                    AvatarOwnershipTransfers::RegistryCancelOperation.call(
                      actor: avatar_actor,
                      surface: "org",
                      subject_public_id: Actor.selection.account_public_id,
                      reservation_public_id: params.expect(:ref),
                    )
                  else
                    AvatarOwnershipTransfers::CancelOperation.call(
                      actor: avatar_actor,
                      surface: "org",
                      subject_public_id: Actor.selection.account_public_id,
                      transfer_public_id: transfer.public_id,
                    )
                  end
                end
              return if performed?

              render_transfer(cancelled, transfer_kind: (registry_transfer? ? "registry" : nil))
            rescue AvatarOwnershipTransfers::Unauthorized
              render_owner_denied
            rescue AvatarOwnershipTransfers::Expired => e
              render json: { error: "expired", message: e.message }, status: :gone
            rescue AvatarOwnershipTransfers::InvalidTransfer => e
              render json: { error: "invalid_transfer", message: e.message }, status: :unprocessable_content
            end

            private

            def find_transfer!
              ::AvatarOwnershipTransfer.find_by(public_id: params.expect(:ref)) || raise(ActiveRecord::RecordNotFound)
            end

            def find_registry_reservation!
              AvatarTransferReservation.find_by(public_id: params.expect(:ref)) || raise(ActiveRecord::RecordNotFound)
            end

            def transfer_params
              keys = %i(target_surface target_collective_public_id)
              params.slice(*keys).permit(*keys).to_h.symbolize_keys
            end

            def registry_transfer?
              params[:transfer_kind].to_s == "registry"
            end

            def registry_request?
              !idempotency_key.nil?
            end

            def ensure_registry_admission_available!
              return if AvatarOwnershipCutover.established?

              raise AvatarOwnershipTransfers::InvalidTransfer,
                    "registry transfer admission requires the verified Avatar ownership cutover"
            end

            def idempotency_key
              request.get_header("HTTP_IDEMPOTENCY_KEY")
            end

            def registry_request_fingerprint
              Digest::SHA256.hexdigest(
                [
                  "avatar_transfer",
                  "org",
                  avatar_actor.public_id,
                  Actor.selection.account_public_id,
                  Actor.selection.avatar_public_id,
                  transfer_params.fetch(:target_surface, ""),
                  transfer_params.fetch(:target_collective_public_id, ""),
                ].join("\0"),
              )
            end

            def render_transfer(transfer, transfer_kind: nil)
              body = { status: transfer.state, transfer_public_id: transfer.public_id }
              body[:transfer_kind] = transfer_kind if transfer_kind
              render json: body
            end
          end
        end
      end
    end
  end
end
