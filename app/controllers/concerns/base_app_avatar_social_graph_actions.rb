# typed: false
# frozen_string_literal: true

# Follow/block/mute for the app Base Self-RP (R5-WU14): each edge change is decided and written by
# the Avatar owner over HTTPS; this RP only relays the owner's answer.
module BaseAppAvatarSocialGraphActions
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    before_action :authenticate_browser_rp!
  end

  public

  def create
    relay_edge(avatar_authority.add_edge(self.class.const_get(:EDGE_KIND, false), params.fetch(:avatar_id)), :created)
  end

  def destroy
    relay_edge(
      avatar_authority.remove_edge(self.class.const_get(:EDGE_KIND, false), params.fetch(:avatar_id)),
      :no_content,
    )
  end

  private

  def avatar_authority
    AvatarAuthorityClient.new(
      surface: "app",
      access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
      persona: Actor.selection.account_public_id,
    )
  end

  def relay_edge(result, success_status)
    authorize!(result, to: :show?, with: AvatarRemoteResultPolicy)
    raise ActiveRecord::RecordNotFound, "avatar not found" if result.status == :not_found
    return head(:service_unavailable) unless result.ok?

    (success_status == :created) ? render(json: result.data, status: :created) : head(:no_content)
  end
end
