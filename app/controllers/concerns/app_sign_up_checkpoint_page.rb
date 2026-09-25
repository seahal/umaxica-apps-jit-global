# typed: false
# frozen_string_literal: true

# The `auth/app` sign-up checkpoint pages, as Inertia props.
#
# The checkpoint screen and the age-restricted screen were ERB templates rendered from
# `SignUpSequenceControllerSupport` and `SignUpSocialCheckBirthdateControllerSupport`. Both of those
# concerns still serve `auth/com`, so this one overrides only the rendering half for the surface
# that has migrated; the requirement computation, the policy checks and the statuses are untouched.
#
# Which requirement sections exist is a server decision taken from the ticket, so a section the
# visitor cannot act on is absent from the props rather than hidden by the page. Nothing about the
# ticket travels except its checkpoint version, which the server re-validates on submission.
module AppSignUpCheckpointPage
  extend ActiveSupport::Concern

  CHECKPOINT_COMPONENT = "auth/app/sign/up/checkpoints/show"
  AGE_RESTRICTED_COMPONENT = "auth/app/sign/up/checkpoints/age_restricted"

  private

  def render_sign_up_checkpoint
    @sign_up_missing_requirements = sign_up_missing_requirements
    @sign_up_completed_requirements = @sign_up_ticket.completed_requirements
    @sign_up_pending_actor = sign_up_pending_actor

    render inertia: CHECKPOINT_COMPONENT, props: sign_up_checkpoint_props, status: :ok
  end

  def sign_up_checkpoint_props
    missing = @sign_up_missing_requirements

    {
      title: t("sign.app.registration.checkpoint.show.page_title"),
      birthdate: missing.include?(:birthdate) ? sign_up_checkpoint_birthdate_props : nil,
      passkey: missing.include?(:passkey) ? sign_up_checkpoint_passkey_props : nil,
      complete_message: missing.empty? ? t("sign.app.registration.checkpoint.show.complete") : nil,
      cancellation: sign_up_checkpoint_cancellation_props(missing.first),
    }
  end

  def sign_up_checkpoint_birthdate_props
    scope = "sign.app.registration.checkpoint.show.birthdate"

    {
      title: page_t("#{scope}.title"),
      description: page_t("#{scope}.description"),
      label: page_t("#{scope}.label"),
      action: public_send(
        :"auth_app_sign_up_check_#{@sign_up_ticket.entry_method}_birthdate_path",
        ri: params[:ri],
        pt: signed_pt_param,
      ),
      submit_label: page_t("#{scope}.submit"),
      checkpoint_version: @sign_up_ticket.checkpoint_version,
      fields: {
        format: helpers.sign_up_birthdate_date_format,
        separator: helpers.sign_up_birthdate_prop_separator,
        parts: helpers.sign_up_birthdate_prop_parts(@sign_up_pending_actor&.birthdate),
      },
    }
  end

  def sign_up_checkpoint_passkey_props
    scope = "sign.app.registration.checkpoint.show.passkey"

    {
      title: page_t("#{scope}.title"),
      description: page_t("#{scope}.description"),
      label: page_t("#{scope}.action"),
      href: auth_app_sign_up_check_telephone_passkey_path(
        ri: params[:ri],
        pt: signed_pt_param,
        checkpoint_version: @sign_up_ticket.checkpoint_version,
      ),
    }
  end

  # The cancellation endpoint is the one belonging to the step the visitor is standing on, which is
  # the first missing requirement; with none missing there is nothing to cancel.
  def sign_up_checkpoint_cancellation_props(step)
    return nil if step.blank?

    {
      label: t("actions.cancel"),
      action: public_send(
        :"auth_app_sign_up_check_#{@sign_up_ticket.entry_method}_#{step}_path",
        ri: params[:ri],
        pt: signed_pt_param,
      ),
    }
  end

  def render_sign_up_age_restricted
    response.headers["Cache-Control"] = "no-store, private"
    @sign_up_age_restricted_message = I18n.t("sign.app.registration.checkpoint.age_restricted")
    @sign_up_age_restricted_restart_path = sign_up_restart_path

    render inertia: AGE_RESTRICTED_COMPONENT,
           props: {
             title: t("sign.app.registration.checkpoint.age_restricted"),
             message: @sign_up_age_restricted_message,
             retry_message: t("sign.app.registration.checkpoint.age_restricted_retry"),
             back: { label: t("actions.back"), href: @sign_up_age_restricted_restart_path },
           },
           status: :ok
  end
end
