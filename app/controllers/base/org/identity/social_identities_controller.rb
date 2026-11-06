# frozen_string_literal: true

class Base::Org::Identity::SocialIdentitiesController < Base::Org::ApplicationController
  include ::SurfaceInertiaPage

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  public

  def index
    authorize!(current_operator, to: :show?)
    linked = OperatorEntraIdentity.exists?(operator_id: current_operator.id, status_id: OperatorEntraIdentityState::ACTIVE)
    render inertia: true, props: {
      title: t("base_social_identities.title"),
      description: t("base_social_identities.org_description"),
      back_link: { label: t("base.shared.identity.up_link"), href: base_org_identity_path(ri: params[:ri]) },
      identities: [{
        provider: "Microsoft Entra ID",
        status: t(linked ? "base_social_identities.linked" : "base_social_identities.unlinked"),
      }],
    }
  end
end
