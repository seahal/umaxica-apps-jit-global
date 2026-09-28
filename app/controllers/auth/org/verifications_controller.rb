# typed: false
# frozen_string_literal: true

class Auth::Org::VerificationsController < ::Auth::Org::Verification::BaseController
  include SignOrgVerificationBase

  include SignVerificationEntry

  include ::SurfaceInertiaPage

  AUTHENTICATION_MODE = :private

  private

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
      notice: flash[:notice].presence,
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

  def verification_success_notice_key
    "sign.org.verification.success.complete"
  end

  def verification_invalid_request_redirect_path(ri:)
    auth_org_settings_path(ri: ri)
  end
end
