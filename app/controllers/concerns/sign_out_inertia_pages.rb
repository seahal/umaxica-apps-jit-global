# typed: false
# frozen_string_literal: true

# Renders the sign-out ceremony pages of an auth surface as Inertia pages.
#
# The confirmation, completion and unavailable screens used to be three ERB templates under
# `app/views/auth/shared/sign_outs`, rendered by name from `SignOutNotice` and
# `OidcRpLogoutLauncher`. A surface page resolver only globs its own directory, so the shared
# markup lives in `src/features/auth/session/*` and each surface owns a page module that re-exports
# it. The component names are derived from `controller_path`, which is what keeps a surface from
# naming another surface's page.
#
# Include it in an auth sign-out controller that also includes `SurfaceInertiaPage`; controllers
# still rendering the ERB templates are unaffected.
module SignOutInertiaPages
  extend ActiveSupport::Concern

  included do
    # Captured at include time so the sign-out controller keeps naming pages from its own surface controller_path.
    prefix = controller_path
    define_method(:sign_out_page_prefix) { prefix }
    private :sign_out_page_prefix
  end

  private

  def sign_out_page_component(name)
    "#{sign_out_page_prefix}/#{name}"
  end

  def sign_out_confirmation_props
    {
      title: t("sign.shared.sign_out.title"),
      heading: t("sign.shared.sign_out.title"),
      active_context: sign_out_active_context_present?,
      confirm_description: t("sign.shared.sign_out.confirm_description"),
      already_signed_out: t("sign.shared.sign_out.already_signed_out"),
      submit_label: t("sign.shared.sign_out.button"),
      form: {
        action: sign_out_confirmation_form_path,
        logout_challenge: params[:logout_challenge].presence,
      },
      cancel: {
        label: t("actions.cancel"),
        action: sign_out_post_path,
      },
      home_link: sign_out_home_link,
    }
  end

  def sign_out_completion_props
    {
      title: t("sign.shared.sign_out.completed_title"),
      heading: t("sign.shared.sign_out.completed_title"),
      description: sign_out_completed_description,
      home_link: sign_out_home_link,
    }
  end

  def sign_out_unavailable_props
    {
      title: t("sign.shared.sign_out.unavailable_title"),
      heading: t("sign.shared.sign_out.unavailable_title"),
      description: t("sign.shared.sign_out.unavailable_description"),
      retry: {
        label: t("sign.shared.sign_out.retry_button"),
        action: sign_out_confirmation_form_path,
      },
      home_link: sign_out_home_link,
    }
  end

  def sign_out_home_link
    { label: t("sign.shared.sign_out.home_link"), href: sign_out_home_path }
  end

  def render_sign_out_confirmation_page
    render inertia: sign_out_page_component("edit"), props: sign_out_confirmation_props
  end

  # `clear_history` is what actually ends the signed-in session's presence in the browser.
  # `encrypt_history` is on globally, but it only encrypts each history entry; the key that decrypts
  # them lives in the tab's own sessionStorage and `reset_session` does not reach it, so without this
  # Back after signing out decrypts and restores the privileged page. Ending a session also sets
  # `session[:inertia_clear_history]` (AuthenticationLogoutable#reset_session_and_clear_inertia_history!),
  # but this completion page can be reached in a later request on a session that no longer
  # carries that flag, so it states the clear itself. The other surfaces' completion renders carry
  # the same option.
  def render_oidc_rp_logout_completion
    @sign_out_notice = consume_sign_out_notice
    render inertia: sign_out_page_component("complete"),
           props: sign_out_completion_props,
           status: :ok,
           clear_history: true
  end

  # The surface guard is the one `OidcRpLogoutLauncher` applies: only the app surface answers an
  # incomplete RP logout with the unavailable screen, the other surfaces answer with completion.
  def render_oidc_rp_logout_unavailable
    return render_oidc_rp_logout_completion unless logout_surface_name == "app"

    render inertia: sign_out_page_component("unavailable"),
           props: sign_out_unavailable_props,
           status: :unprocessable_content
  end
end
