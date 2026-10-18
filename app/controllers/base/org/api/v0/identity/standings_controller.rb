# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Identity
          # Account standing owner for the org Base Self-RP (R5-WU12): the Enforcement owner
          # resolves the actor's visible decisions; the page is relayed unchanged.
          class StandingsController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionController::MimeResponds
            include AbstractController::Translation
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint
            include ::OwnerPageResponses

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "org"

            authorize :user, through: :avatar_actor
            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            before_action :apply_browser_context
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden

            public

            def show
              authorize!(avatar_actor, to: :show?)
              @standing = AccountStandingResolver.call(
                enforcement_case_class: OrgEnforcementCase,
                principal_public_id: avatar_actor.public_id,
              )
              render inertia: true, props: {
                title: "Account Standing",
                status_label: "Current status: #{@standing.level.to_s.humanize}",
                up_link: { label: t("actions.up"), href: base_org_identity_path(ri: params[:ri]) },
                decisions: @standing.decisions.map { |decision| serialize_decision(decision) },
              }
            end

            private

            def serialize_decision(decision)
              expires_at = decision.fetch(:expires_at)

              {
                public_id: decision.fetch(:public_id),
                kind: decision.fetch(:kind).humanize,
                reason: decision.fetch(:reason_code).humanize,
                ends_at: expires_at.present? ? "Ends: #{l(expires_at)}" : nil,
              }
            end

            private

            def l(...) = I18n.l(...)
          end
        end
      end
    end
  end
end
