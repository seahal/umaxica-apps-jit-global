# frozen_string_literal: true

class Base::App::Identity::SocialIdentitiesController < Base::App::Identity::BaseController
  include ::SurfaceInertiaPage

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  public

  def index
    authorize!(current_client, to: :show?)
    render inertia: true, props: {
      title: t("base_social_identities.title"),
      description: t("base_social_identities.description"),
      back_link: { label: t("base.shared.identity.up_link"), href: base_app_identity_path(ri: params[:ri]) },
      identities: %w(google apple).map do |provider|
        {
          provider: (provider == "google") ? "Google" : "Apple",
          status: t(
            current_client.active_social_provider?(provider) ?
                        "base_social_identities.linked" : "base_social_identities.unlinked",
          ),
        }
      end,
    }
  end
end
