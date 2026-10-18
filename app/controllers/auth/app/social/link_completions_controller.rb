# frozen_string_literal: true

module Auth
  module App
    module Social
      class LinkCompletionsController < ::Auth::App::ApplicationController
        include SocialAuth
        include VerificationClient

        AUTHENTICATION_MODE = :private
        protect_from_forgery using: :header_or_legacy_token, with: :exception

        public

        def create
          authorize!(current_client, to: :update?)
          response.headers["Cache-Control"] = "private, no-store"
          response.headers["Referrer-Policy"] = "no-referrer"
          response.headers["Content-Security-Policy"] = "frame-ancestors 'none'; form-action 'self'"
          reference = params[:candidate_ref]
          unless IdentitySocialCeremonyCandidate.valid_reference?(reference)
            raise ActionController::BadRequest
          end

          marker = session[SocialAuth::SOCIAL_LINK_COMPLETION_SESSION_KEY]
          token = current_session
          unless marker.is_a?(Array) && marker.length == 2 && marker.first == reference &&
              token && marker.last == token.public_id && current_client
            raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
          end

          current_client.with_lock do
            OpBaseAppRecord.connected_to(role: :writing) do
              device_session = token.device_session_record!
              device_session.with_lock do
                token.with_lock { commit_link_candidate!(reference, token, device_session) }
              end
            end
          end
          session.delete(SocialAuth::SOCIAL_LINK_COMPLETION_SESSION_KEY)
          redirect_to(auth_app_settings_path(ri: params[:ri]), status: :see_other)
        rescue IdentitySocialCeremonyContract::Error, ActiveRecord::RecordNotFound, ActionController::BadRequest
          head :bad_request
        rescue SocialAuth::BaseError => e
          render plain: e.message, status: e.status_code
        end

        private

        def commit_link_candidate!(reference, token, device_session)
          now = token.class.database_now
          unless current_client.login_allowed? && token.active_status?(now) && device_session.usable? &&
              device_session.current_refresh_token_id == token.id
            raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in")
          end

          authorize_social_auth_link!(current_client)
          require_recent_step_up!
          record = IdentitySocialCeremonyCandidate.lock.find_by!(ref: reference)
          unless record.surface == "app" && record.operation == "link" &&
              record.actor_ref == current_client.public_id && record.session_ref == device_session.public_id &&
              record.consumed_at.nil? && record.expires_at > now
            raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
          end

          candidate = IdentitySocialCeremonyCandidateStore.fetch!(reference)
          grant = ClientSocialCeremonyTransaction.lock.find_by!(transaction_id: record.transaction_id)
          validate_link_grant!(grant, candidate, device_session, now)

          ExternalAuthenticationLinkUseCase.call(
            principal: candidate.callback_result.principal,
            credential_candidate: candidate.callback_result.credential_candidate,
            user: current_client,
            ceremony_started_at: grant.created_at,
          )
          record.consume!(
            now: now, error_class: IdentitySocialCeremonyContract::Error,
            not_found_message: "social link candidate unavailable", expired_message: "social link candidate expired",
          )
          grant.expire!
        end

        def validate_link_grant!(grant, candidate, device_session, now)
          return if grant.operation == "link" && grant.provider == candidate.provider &&
            grant.actor_ref == current_client.public_id &&
            grant.session_ref == device_session.public_id &&
            grant.status == SocialCeremonyTransactionable::STATUS_PENDING &&
            grant.consumed_at.nil? && grant.expires_at > now

          raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
        end
      end
    end
  end
end
