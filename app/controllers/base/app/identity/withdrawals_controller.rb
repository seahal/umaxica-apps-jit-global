# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class WithdrawalsController < BaseController
        include ::SurfaceInertiaPage
        include VerificationClient

        include BaseSettingsWithdrawalFlow
        include WithdrawalCeremonyAuthentication

        AUTHENTICATION_MODE = :open

        declare_authentication_mode! :open

        before_action :withdrawal_ceremony_required!, only: %i(edit create destroy)
        before_action :authorize_withdrawal!, only: %i(new update)
        before_action :authorize_withdrawal_ceremony!, only: %i(edit create destroy)
        def new
          render_withdrawal_entry(current_client); render_withdrawal_new unless performed?
        end

        def edit
          render_withdrawal_status(current_withdrawal_subject)
          render_withdrawal_edit unless performed?
        end

        def create = recover_withdrawal!(current_withdrawal_subject)

        def update = update_withdrawal!(current_client)

        def destroy = terminate_withdrawal!(current_withdrawal_subject)

        private

        def authorize_withdrawal! = authorize!(current_client, to: :"#{action_name}?", with: ClientWithdrawalPolicy)

        def authorize_withdrawal_ceremony!
          authorize!(
            current_withdrawal_subject,
            to: :"#{action_name}?",
            with: ClientWithdrawalPolicy,
            context: { user: current_withdrawal_subject },
          )
        end

        def withdrawal_ceremony_class = ClientWithdrawalCeremony

        def withdrawal_new_path(extra_params = {})
          new_base_app_identity_withdrawal_path({ ri: params[:ri] }.merge(extra_params))
        end

        def withdrawal_session_new_path
          new_base_app_identity_withdrawal_session_path(ri: params[:ri])
        end

        def withdrawal_edit_path = edit_base_app_identity_withdrawal_path(ri: params[:ri])

        def withdrawal_settings_path = base_app_identity_withdrawal_path(ri: params[:ri])

        def withdrawal_public_fallback_path = auth_app_sign_in_path

        def handle_deactivation_failure(_actor)
          @schedule_confirmed = true; render_withdrawal_new(status: :unprocessable_content)
        end

        def render_withdrawal_new(status: :ok)
          render inertia: "base/app/identity/withdrawals/new", props: withdrawal_new_props, status: status
        end

        def render_withdrawal_edit(status: :ok)
          render inertia: "base/app/identity/withdrawals/edit", props: withdrawal_edit_props, status: status
        end

        def withdrawal_new_props
          {
            title: t("sign.app.settings.withdrawal.new.page_title"),
            already_deactivated: current_client.deactivated?,
            already_deactivated_message: t("sign.app.settings.withdrawal.new.already_deactivated"),
            recovery_link: {
              label: t("sign.app.settings.withdrawal.recovery.link"),
              href: edit_base_app_identity_withdrawal_path(ri: params[:ri]),
            },
            schedule: {
              title: t("sign.app.settings.withdrawal.schedule.title"),
              ack_label: t("sign.app.settings.withdrawal.schedule.ack_label"),
              submit_label: t("sign.app.settings.withdrawal.schedule.submit"),
              acknowledged: @schedule_form.ack_schedule_purge.to_s == "1",
              action: base_app_identity_withdrawal_path(ri: params[:ri]),
              errors: @schedule_form.errors.full_messages,
            },
            deactivate: @schedule_confirmed ? withdrawal_deactivate_props : nil,
          }
        end

        def withdrawal_deactivate_props
          {
            title: t("sign.app.settings.withdrawal.deactivate.title"),
            ack_label: t("sign.app.settings.withdrawal.deactivate.ack_label"),
            submit_label: t("sign.app.settings.withdrawal.deactivate.submit"),
            confirm: t("sign.app.settings.withdrawal.deactivate.confirm"),
            action: base_app_identity_withdrawal_path(ri: params[:ri]),
            errors: @deactivate_form.errors.full_messages,
          }
        end

        def withdrawal_edit_props
          {
            title: t("sign.app.settings.withdrawal.recovery.page_title"),
            terminated: @terminated,
            unavailable_message: t("sign.app.settings.withdrawal.recovery.unavailable"),
            deadline_message: @terminated ?
              nil : t(
                "sign.app.settings.withdrawal.recovery.deadline",
                date: I18n.l(@recovery_deadline, format: :long),
              ),
            recovery: withdrawal_recovery_props,
            termination: withdrawal_termination_props,
            erasure_link: {
              label: "Request early personal data erasure",
              href: new_base_app_identity_privacy_erasure_path(ri: params[:ri]),
            },
            sign_out: {
              label: t("sign.shared.sign_out.button"),
              url: base_app_identity_withdrawal_session_path(ri: params[:ri]),
            },
          }
        end

        def withdrawal_recovery_props
          return nil if @terminated
          if @recoverable
            return {
              available_message: t("sign.app.settings.withdrawal.recovery.available"),
              submit_label: t("sign.app.settings.withdrawal.recovery.submit"),
              confirm: t("sign.app.settings.withdrawal.recovery.confirm"),
              action: base_app_identity_withdrawal_path(ri: params[:ri]),
              unavailable_message: nil,
            }
          end

          pending = @recovery_available_at.present? && Time.current < @recovery_available_at
          {
            available_message: nil,
            submit_label: nil,
            confirm: nil,
            action: nil,
            unavailable_message: pending ?
              t("sign.app.settings.withdrawal.recovery.deadline", date: I18n.l(@recovery_available_at, format: :long)) :
              t("sign.app.settings.withdrawal.recovery.unavailable"),
          }
        end

        def withdrawal_termination_props
          return nil if @terminated
          if @early_terminatable
            return {
              submit_label: t("sign.app.settings.withdrawal.terminate.submit"),
              confirm: t("sign.app.settings.withdrawal.terminate.confirm"),
              action: base_app_identity_withdrawal_path(ri: params[:ri]),
              available_at_message: nil,
            }
          end
          return nil if @early_termination_available_at.blank?

          {
            submit_label: nil,
            confirm: nil,
            action: nil,
            available_at_message: t(
              "sign.app.settings.withdrawal.terminate.available_at",
              date: I18n.l(@early_termination_available_at, format: :long),
            ),
          }
        end

        def verification_required_action? = action_name.in?(%w(new update))

        def verification_scope = "withdrawal"
      end
    end
  end
end
