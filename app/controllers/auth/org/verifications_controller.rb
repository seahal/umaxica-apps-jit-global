# typed: false
# frozen_string_literal: true

class Auth::Org::VerificationsController < ::Auth::Org::ApplicationController
  include AuthCeremonyAdmission
  include AuthStepUpCeremonyContext
  include AuthStepUpCeremonyEntry

  include ::SurfaceInertiaPage

  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  private

  def ceremony_actor_model = Operator

  def ceremony_step_up_session_model = OperatorStepUpSession

  def ceremony_session_token(session_record) = session_record.staff_token

  def ceremony_token_owned_by?(token, actor) = token.staff_id == actor.id && !token.emergency_authentication_context?

  def authorize_step_up_ceremony_actor!(actor)
    authorize!(actor, to: :show?, context: { user: actor })
  end

  def ceremony_supported_methods = %i(passkey)

  def auth_step_up_ceremony_clean_url = auth_org_verification_path(ri: params[:ri])

  def step_up_cancellation_props
    { label: t("actions.cancel"), action: auth_org_verification_cancellation_path(ri: params[:ri]), method: "post" }
  end

  def render_verification_entry_page
    render inertia: "auth/org/verifications/show", props: verification_entry_props
  end

  # A method the actor has not configured is absent from `methods` rather than rendered and hidden.
  def verification_entry_props
    methods = Array(@available_methods)

    {
      title: t("sign.org.verification.index.title"),
      section_title: t("sign.org.verification.new.title"),
      section_description: t("sign.org.verification.new.description"),
      notice: nil,
      cancel: step_up_cancellation_props,
      no_methods: (t("views.sign.org.verifications.show.no_methods") if methods.blank?),
      methods: if methods.include?(:passkey)
                 [{
                   key: "passkey",
                   label: t("sign.org.verification.new.methods.passkey"),
                   href: new_auth_org_verification_passkey_path(ri: params[:ri]),
                 }]
               else
                 []
               end,
    }
  end
end
