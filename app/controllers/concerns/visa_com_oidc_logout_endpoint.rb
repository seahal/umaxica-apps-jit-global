# typed: false
# frozen_string_literal: true

# Supplies the logout rendering and protocol methods to the realm's authority controllers.
module VisaComOidcLogoutEndpoint
  extend ActiveSupport::Concern

  include CommonRedirect
  include ::AuthenticationLogoutable
  include SignOutNotice
  include SignOidcLogout
  include ::SurfaceInertiaPage

  private

  def oidc_logout_completed_path(ri:, _sot: nil)
    visa_com_oidc_logout_completion_path(ri: ri)
  end

  def sign_out_edit_path(**) = visa_com_oidc_logout_path(**)

  def sign_out_post_path(**options)
    return request.path if options.compact.empty?

    "#{request.path}?#{options.compact.to_query}"
  end

  def sign_out_home_path(**) = visa_com_oidc_logout_completion_path(**)

  # The ERB template this action rendered was a two-line wrapper around the shared sign-out
  # confirmation, so both the confirmation and the completion path render the same Inertia
  # page here.
  def render_oidc_end_session_confirmation
    render inertia: "visa/com/oidc/logouts/show", props: sign_out_edit_page_props, status: :ok
  end

  def render_oidc_logout_completion
    @sign_out_notice = consume_sign_out_notice
    return head(:not_found) unless @sign_out_notice && @sign_out_notice[:face] == sign_surface_name

    render_oidc_signed_out
  end

  def render_oidc_signed_out
    render_oidc_logout_result_page(
      title: t("sign.shared.sign_out.completed_title"),
      description: t("sign.shared.sign_out.completed_description"),
      status: :ok,
    )
  end

  def render_oidc_rp_logout_indeterminate
    render_oidc_logout_result_page(
      title: t("sign.shared.sign_out.indeterminate_title"),
      description: t("sign.shared.sign_out.indeterminate_description"),
      status: :service_unavailable,
    )
  end

  def render_oidc_logout_result_page(title:, description:, status:)
    render inertia: "visa/com/oidc/logouts/show",
           props: {
             title: title,
             active: false,
             description: description,
             form: nil,
             home_link: { label: t("sign.shared.sign_out.home_link"), href: visa_com_root_path },
           },
           status: status,
           clear_history: true
  end

  def sign_out_edit_page_props
    active = sign_out_active_context_present?

    {
      title: t("sign.shared.sign_out.title"),
      active: active,
      description: active ? t("sign.shared.sign_out.confirm_description") :
        t("sign.shared.sign_out.already_signed_out"),
      form: active ? sign_out_confirmation_form : nil,
      home_link: { label: t("sign.shared.sign_out.home_link"), href: visa_com_root_path },
    }
  end

  def sign_out_confirmation_form
    {
      action: sign_out_confirmation_form_path,
      submit: t("sign.shared.sign_out.button"),
      ri: params[:ri].presence,
      confirm_description: t("sign.shared.sign_out.confirm_description"),
    }
  end
end
