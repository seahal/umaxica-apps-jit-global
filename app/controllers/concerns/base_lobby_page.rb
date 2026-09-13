# typed: false
# frozen_string_literal: true

# Shared GET /lobby rendering for Base app, com, and org.
#
# Authenticated actors never see the lobby: they are sent to the surface dashboard. Anonymous
# actors receive the unauthenticated entry page. A just-completed sign-out stores a one-time
# `SignOutNotice` in the fresh session; this page consumes it so a later GET does not keep showing
# the completion message.
module BaseLobbyPage
  private

  def render_lobby_page
    if logged_in?
      redirect_to(lobby_dashboard_path)
      return
    end

    notice = consume_sign_out_notice
    render inertia: true,
           props: lobby_page_props(notice),
           clear_history: notice.present?
  end

  def lobby_dashboard_path
    public_send("#{lobby_route_prefix}_dashboard_path", ri: params[:ri])
  end

  def lobby_page_props(notice)
    {
      title: t("base.shared.lobby.title"),
      heading: t("base.shared.lobby.heading"),
      description: t("base.shared.lobby.description"),
      sign_in: {
        label: t("base.shared.lobby.sign_in"),
        href: public_send(
          "#{lobby_route_prefix}_oidc_authorization_path",
          ri: params[:ri],
          screen_hint: "signin",
        ),
      },
      notice: lobby_notice_props(notice),
    }
  end

  def lobby_notice_props(notice)
    return if notice.blank?

    expires_at = notice[:access_expires_at]
    {
      title: t("sign.shared.sign_out.completed_title"),
      description: expires_at.blank? ? nil : t(
        "sign.shared.sign_out.completed_description",
        expires_at: l(expires_at, format: :short),
      ),
    }
  end

  def lobby_route_prefix
    family, surface = controller_path.split("/").first(2)
    "#{family}_#{surface}"
  end
end
