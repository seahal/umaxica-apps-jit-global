# typed: false
# frozen_string_literal: true

# The `auth/app` sign-up entry page, as Inertia props.
#
# Two callers render it: `Auth::App::Sign::UpsController`, which is the page's own route, and
# `SignUpSuspensionGuard`, which answers a suspended registration with the same page carrying the
# notice instead of the entry points. Both need the identical payload, and neither may compute it in
# a view any more, so it lives here.
#
# Every label is translated and every destination is generated here: the page receives finished
# strings and finished paths. The Apple artwork is included only when the official files are in the
# repository, which is the constraint
# `docs/reference/third-party-sign-in-button-requirements.md` places on the button.
module AppSignUpEntryPage
  extend ActiveSupport::Concern

  SIGN_UP_ENTRY_COMPONENT = "auth/app/sign_ups/new"

  private

  def sign_up_entry_page_props(suspended_notice: nil)
    {
      title: t("sign.app.registration.new.page_title"),
      cancel_label: t("actions.cancel"),
      suspended_notice: suspended_notice,
      methods: suspended_notice ? [] : sign_up_entry_methods,
      social_providers: suspended_notice ? [] : sign_up_entry_social_providers,
      links: suspended_notice ? [] : sign_up_entry_links,
    }
  end

  def sign_up_entry_methods
    [
      {
        key: "email",
        label: t("sign.app.registration.new.methods.email.cta"),
        href: new_auth_app_sign_up_email_path(ri: params[:ri]),
      },
      {
        key: "telephone",
        label: t("sign.app.registration.new.methods.telephone.cta"),
        href: new_auth_app_sign_up_telephone_path(ri: params[:ri]),
      },
    ]
  end

  # The provider buttons post directly: the press supplies the CSRF token the OmniAuth request phase
  # requires, so no cushion page is involved.
  def sign_up_entry_social_providers
    [
      {
        provider: "google",
        label: t("sign.app.registration.new.social.buttons.google"),
        url: auth_app_social_google_registration_path(ri: params[:ri]),
        apple_logos: nil,
      },
      {
        provider: "apple",
        label: t("sign.app.registration.new.social.buttons.apple"),
        url: auth_app_social_apple_registration_path(ri: params[:ri]),
        apple_logos: helpers.apple_sign_in_logo_paths,
      },
    ]
  end

  def sign_up_entry_links
    [
      {
        key: "sign_in",
        label: t("sign.app.registration.new.links.sign_in"),
        href: auth_app_sign_in_path,
      },
    ]
  end

  # `SignUpSuspensionGuard` renders the surface's own entry page; on this surface that page is an
  # Inertia component rather than a template, and the 503 stays exactly as it was.
  def render_suspended_sign_up!
    render inertia: SIGN_UP_ENTRY_COMPONENT,
           props: sign_up_entry_page_props(suspended_notice: t("errors.messages.sign_up_suspended")),
           status: :service_unavailable
  end
end
