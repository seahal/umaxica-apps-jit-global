# typed: false
# frozen_string_literal: true

# The `auth/app` sign-up entry page, as Inertia props.
#
# The page controller owns this payload. Availability refusal is handled by
# Sign Entry Sentry before this page is rendered.
#
# Every label is translated and every destination is generated here: the page receives finished
# strings and finished paths. The Apple artwork is included only when the official files are in the
# repository, which is the constraint
# `docs/reference/third-party-sign-in-button-requirements.md` places on the button.
module AppSignUpEntryPage
  extend ActiveSupport::Concern
  include SignEntryExit

  SIGN_UP_ENTRY_COMPONENT = "auth/app/sign_ups/new"

  private

  def sign_up_entry_page_props
    {
      title: t("sign.app.registration.new.page_title"),
      suspended_notice: nil,
      methods: sign_up_entry_methods,
      social_providers: sign_up_entry_social_providers,
      links: sign_entry_parent_bound? ? [] : sign_up_entry_links,
      **sign_entry_exit_forms(switch_to: "sign_in", switch_label: t("sign.app.registration.new.links.sign_in")),
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

  def sign_entry_exit_sign_up_cycle_class = ClientSignUpFlow

  def sign_entry_exit_cancellation_path = auth_app_sign_cancellation_path(ri: params[:ri])

  def sign_entry_exit_switch_path = auth_app_sign_switch_path(ri: params[:ri])

  def sign_up_entry_links
    [
      {
        key: "sign_in",
        label: t("sign.app.registration.new.links.sign_in"),
        href: auth_app_sign_in_path,
      },
    ]
  end
end
