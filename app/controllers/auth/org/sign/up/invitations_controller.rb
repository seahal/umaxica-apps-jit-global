# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module Up
        class InvitationsController < ::Auth::Org::ApplicationController
          include CloudflareTurnstile
          include ::TurnstilePageProps
          include ::SurfaceInertiaPage
          include ::MinimumResponseBudget

          AUTHENTICATION_MODE = :guest

          before_action :start_minimum_response_budget, only: :create
          after_action :enforce_minimum_response_budget, only: :create

          def new
            @invitation_code = params[:invitation_code].to_s
            render inertia: true, props: invitation_props
          end

          def create
            @invitation_code = params[:invitation_code].to_s

            unless cloudflare_turnstile_validation["success"]
              @form_error = t(".turnstile_failed")
              render inertia: "auth/org/sign/up/invitations/new",
                     props: invitation_props,
                     status: :unprocessable_content
              return
            end

            # Provisioning is closed for every code during Bureau migration. Refuse
            # before lookup so neither response contents nor lookup work classify codes.
            @form_error = ::OrgInvitationService::MIGRATION_REQUIRED_MESSAGE
            render inertia: "auth/org/sign/up/invitations/new",
                   props: invitation_props,
                   status: :unprocessable_content
          end

          private

          def invitation_props
            {
              title: t("sign.org.up.invitations.new.title"),
              description: t("sign.org.up.invitations.new.description"),
              form_error: @form_error.presence,
              form_action: auth_org_sign_up_invitations_path,
              invitation_code_label: t("sign.org.up.invitations.form.invitation_code"),
              invitation_code: @invitation_code.to_s,
              submit_label: t("sign.org.up.invitations.form.submit"),
              back_link: { label: t("sign.org.in.back"), href: auth_org_sign_in_path },
              turnstile: turnstile_visible_props,
            }
          end

          def sign_up_surface = :org

        end
      end
    end
  end
end
