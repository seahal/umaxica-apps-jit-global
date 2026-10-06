# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class WithdrawalsController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::VerificationVisitor
        include CommonRedirect
        include BaseSettingsWithdrawalFlow
        include WithdrawalCeremonyAuthentication

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        before_action :withdrawal_ceremony_required!, only: %i(edit create destroy)
        before_action :authorize_withdrawal!, only: %i(new update)
        before_action :authorize_withdrawal_ceremony!, only: %i(edit create destroy)

        def new
          render_withdrawal_entry(current_visitor)
          render_withdrawal_new unless performed?
        end

        def edit
          render_withdrawal_status(current_withdrawal_subject)
          render inertia: true, props: edit_page_props unless performed?
        end

        def create
          recover_withdrawal!(current_withdrawal_subject)
        end

        def update
          update_withdrawal!(current_visitor)
        end

        def destroy
          terminate_withdrawal!(current_withdrawal_subject)
        end

        private

        # Overrides the shared flow's transport seam: the entry screen is an Inertia page on this
        # surface. The status the flow asks for is passed straight through.
        def render_withdrawal_new(status: :ok)
          render inertia: "base/com/identity/withdrawals/new", props: new_page_props, status: status
        end

        def new_page_props
          {
            title: t("sign.app.settings.withdrawal.new.page_title"),
            already_deactivated: current_visitor.deactivated?,
            already_deactivated_message: t("sign.app.settings.withdrawal.new.already_deactivated"),
            recovery_link: {
              label: t("sign.app.settings.withdrawal.recovery.link"),
              href: edit_base_com_identity_withdrawal_path(ri: params[:ri]),
            },
            schedule: {
              title: t("sign.app.settings.withdrawal.schedule.title"),
              errors: @schedule_form.errors.full_messages,
              url: new_base_com_identity_withdrawal_path(ri: params[:ri]),
              method: "get",
              field: "ack_schedule_purge",
              ack_label: t("sign.app.settings.withdrawal.schedule.ack_label"),
              checked: @schedule_form.ack_schedule_purge.to_s == "1",
              submit_label: t("sign.app.settings.withdrawal.schedule.submit"),
            },
            deactivate: deactivate_section_props,
          }
        end

        # The deactivation step only exists once the schedule has been acknowledged, so an actor who
        # has not reached it is not sent the form at all.
        def deactivate_section_props
          return unless @schedule_confirmed

          {
            title: t("sign.app.settings.withdrawal.deactivate.title"),
            errors: @deactivate_form.errors.full_messages,
            url: base_com_identity_withdrawal_path(ri: params[:ri]),
            method: "patch",
            field: "ack_deactivate_today",
            ack_label: t("sign.app.settings.withdrawal.deactivate.ack_label"),
            submit_label: t("sign.app.settings.withdrawal.deactivate.submit"),
            confirm: t("sign.app.settings.withdrawal.deactivate.confirm"),
          }
        end

        def edit_page_props
          {
            title: t("sign.app.settings.withdrawal.recovery.page_title"),
            terminated: @terminated,
            unavailable_message: t("sign.app.settings.withdrawal.recovery.unavailable"),
            deadline_message: withdrawal_deadline_message(@recovery_deadline),
            recovery: withdrawal_recovery_section_props,
            termination: withdrawal_termination_section_props,
            privacy_erasure_link: {
              label: "Request early personal data erasure",
              href: new_base_com_identity_privacy_erasure_path(ri: params[:ri]),
            },
            sign_out: {
              label: t("sign.shared.sign_out.button"),
              url: base_com_identity_withdrawal_session_path(ri: params[:ri]),
            },
          }
        end

        def withdrawal_deadline_message(deadline)
          return if deadline.blank?

          t("sign.app.settings.withdrawal.recovery.deadline", date: l(deadline, format: :long))
        end

        def withdrawal_recovery_section_props
          if @recoverable
            return {
              available_message: t("sign.app.settings.withdrawal.recovery.available"),
              url: base_com_identity_withdrawal_path(ri: params[:ri]),
              submit_label: t("sign.app.settings.withdrawal.recovery.submit"),
              confirm: t("sign.app.settings.withdrawal.recovery.confirm"),
            }
          end

          if @recovery_available_at.present? && Time.current < @recovery_available_at
            return { pending_message: withdrawal_deadline_message(@recovery_available_at) }
          end

          { unavailable_message: t("sign.app.settings.withdrawal.recovery.unavailable") }
        end

        def withdrawal_termination_section_props
          if @early_terminatable
            return {
              url: base_com_identity_withdrawal_path(ri: params[:ri]),
              submit_label: t("sign.app.settings.withdrawal.terminate.submit"),
              confirm: t("sign.app.settings.withdrawal.terminate.confirm"),
            }
          end

          return if @early_termination_available_at.blank?

          {
            pending_message: t(
              "sign.app.settings.withdrawal.terminate.available_at",
              date: l(@early_termination_available_at, format: :long),
            ),
          }
        end

        def authorize_withdrawal!
          authorize!(current_visitor, to: :"#{action_name}?", with: VisitorWithdrawalPolicy)
        end

        def authorize_withdrawal_ceremony!
          authorize!(
            current_withdrawal_subject,
            to: :"#{action_name}?",
            with: VisitorWithdrawalPolicy,
            context: { user: current_withdrawal_subject },
          )
        end

        def withdrawal_ceremony_class = VisitorWithdrawalCeremony

        def withdrawal_new_path(extra_params = {})
          new_base_com_identity_withdrawal_path({ ri: params[:ri] }.merge(extra_params))
        end

        def withdrawal_session_new_path
          new_base_com_identity_withdrawal_session_path(ri: params[:ri])
        end

        def withdrawal_edit_path
          edit_base_com_identity_withdrawal_path(ri: params[:ri])
        end

        def withdrawal_settings_path
          base_com_identity_withdrawal_path(ri: params[:ri])
        end

        def withdrawal_public_fallback_path
          auth_com_sign_in_path
        end

        def handle_deactivation_failure(actor)
          Rails.logger.info(
            JitLogEvent.format(
              "visitor.withdrawal.suspension_failed",
              visitor_id: actor.id,
              errors: actor.errors.full_messages,
              ip_address: request.remote_ip,
            ),
          )
          @schedule_confirmed = true
          render_withdrawal_new(status: :unprocessable_content)
        end

        def render_update_validation_error
          @schedule_confirmed = true
          render_withdrawal_new(status: :unprocessable_content)
        end

        def verification_required_action? = action_name.in?(%w(new update))

        def verification_scope = "withdrawal"
      end
    end
  end
end
