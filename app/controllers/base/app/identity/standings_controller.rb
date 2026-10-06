# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class StandingsController < BaseController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        def show
          authorize!(current_client, to: :show?)
          @standing = AccountStandingResolver.call(
            enforcement_case_class: AppEnforcementCase,
            principal_public_id: current_client.public_id,
          )
          render inertia: true, props: {
            title: "Account Standing",
            status_label: "Current status: #{@standing.level.to_s.humanize}",
            up_link: { label: t("actions.up"), href: base_app_identity_path(ri: params[:ri]) },
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
      end
    end
  end
end
