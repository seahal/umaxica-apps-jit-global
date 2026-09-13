# typed: false
# frozen_string_literal: true

# Builds the shared Inertia props that the React surface layout renders as page chrome.
#
# Before the Inertia migration this data was read straight out of the ERB layout by helpers
# (`current_banner_for`, `t(...)`, `*_url`). A React layout cannot reach any of that, so the chrome
# becomes a serialized prop shared by every Inertia response of the surface. Everything that is a
# server responsibility stays here: translation, route generation, the banner query, and the
# decision about which navigation a visitor is allowed to see.
#
# The shared payload is per surface by construction: each including controller declares its own
# family, surface and banner domain, and `inertia_share` runs in that controller's instance, so one
# surface can never publish another surface's chrome.
module SurfaceChrome
  extend ActiveSupport::Concern

  # Query parameters that carry preference context across hosts. The cookie settings link has to
  # forward them or the destination loses the visitor's region and display preferences.
  PREFERENCE_QUERY_KEYS = %w(ri lx ct tz cu df tf mo dn ps).freeze

  # Chrome differs per family, not per controller, so the defaults live here instead of being
  # repeated by every Inertia controller. `banner_domain` selects the banner stream the family
  # answers with (`auth` reads `sign`, `base` reads `acme`); nil opts out of the banner, which is
  # what the families without a banner region do. `footer_navigation` marks the families whose
  # layout carries the cross-host footer links (dashboard/home, preference, settings).
  FAMILY_CHROME = {
    "base" => { family_label: "BASE", banner_domain: :acme, footer_navigation: false },
    "auth" => { family_label: nil, banner_domain: :sign, footer_navigation: true },
    "core" => { family_label: "CORE", banner_domain: nil, footer_navigation: false },
    "side" => { family_label: "SIDE", banner_domain: nil, footer_navigation: false },
    "palm" => { family_label: "PALM", banner_domain: nil, footer_navigation: false },
    "edit" => { family_label: "EDIT", banner_domain: nil, footer_navigation: false },
  }.freeze

  # The operational surfaces are mounted with a route prefix that does not match their controller
  # module, so route helpers cannot be composed from the module name alone.
  SURFACE_ROUTE_NAMES = { "dev" => "developer", "net" => "network" }.freeze

  # Only the three user-facing surfaces have a preference authority to send a visitor to, so the
  # operational surfaces render no cookie or theme controls rather than linking to a host that
  # does not exist.
  PREFERENCE_SURFACES = %w(app com org).freeze

  included do
    inertia_share chrome: -> { surface_chrome }
  end

  private

  def chrome_configuration
    @chrome_configuration ||=
      begin
        family, surface = controller_path.to_s.split("/").first(2)
        defaults =
          FAMILY_CHROME.fetch(family) do
            raise ArgumentError,
                  "#{self.class.name} renders Inertia pages from an unknown family #{family.inspect}; " \
                  "add its chrome to SurfaceChrome::FAMILY_CHROME rather than rendering chromeless pages"
          end

        defaults.merge(family: family, surface: surface).freeze
      end
  end

  def surface_chrome
    configuration = chrome_configuration

    {
      family_label: configuration.fetch(:family_label),
      surface: configuration.fetch(:surface),
      brand: chrome_brand,
      banner: chrome_banner(configuration.fetch(:banner_domain)),
      restricted_mode: chrome_restricted_mode,
      footer_navigation: configuration.fetch(:footer_navigation) ? chrome_footer_navigation : nil,
      cookie_controls: chrome_preference_surface? ? chrome_cookie_controls : nil,
      theme_controls: chrome_preference_surface? ? chrome_theme_controls : nil,
      copyright: chrome_copyright,
    }
  end

  # Restricted Mode (Emergency Access) is a property of the session, not of a
  # page, so it is published once here and rendered by the persistent layout.
  # No screen can omit the indicator, because no screen supplies it: a page that
  # forgets about Emergency Access still renders inside the same chrome.
  #
  # The decision comes from the session row the request authenticated against --
  # the same authority that mints the `authn_ctx` claim -- never from a request
  # parameter, a cookie the browser can write, or page state.
  #
  # Hiding navigation is not authorization. The banner and the trimmed
  # navigation are there so the operator understands what they are looking at;
  # the server denies the unavailable operations regardless
  # (docs/security/org-emergency-access.md).
  def chrome_restricted_mode
    return nil unless chrome_authentication_context.emergency?

    scope = "layouts.shared.restricted_mode"
    {
      label: chrome_t("#{scope}.label"),
      description: chrome_t("#{scope}.description"),
      sign_out: {
        label: chrome_t("#{scope}.sign_out"),
        href: chrome_url(
          "new_#{chrome_configuration.fetch(:family)}_#{chrome_route_surface}_sign_out_path",
          { ri: current_region_identifier },
        ),
      },
    }
  end

  # A surface with no authenticated session, and a surface whose sessions cannot
  # carry a context at all, are both Normal by construction rather than by a
  # lookup that could be made to answer otherwise.
  def chrome_authentication_context
    return AuthenticationContextValue.normal unless respond_to?(:current_session, true)

    session_record = current_session
    return AuthenticationContextValue.normal if session_record.blank?

    session_record.authentication_context_value
  end

  def chrome_brand
    {
      name: ENV.fetch("BRAND_NAME"),
      href: chrome_url("#{chrome_configuration.fetch(:family)}_#{chrome_route_surface}_root_path"),
    }
  end

  def chrome_route_surface
    SURFACE_ROUTE_NAMES.fetch(chrome_configuration.fetch(:surface)) { chrome_configuration.fetch(:surface) }
  end

  def chrome_preference_surface?
    PREFERENCE_SURFACES.include?(chrome_configuration.fetch(:surface))
  end

  # The banner query previously ran inside a layout partial on every response. It stays server-side
  # but moves out of the view, because a React layout cannot reach a Rails helper.
  def chrome_banner(domain)
    return nil if domain.blank?

    banner = CurrentBannerQuery.call(
      tld: chrome_configuration.fetch(:surface).to_sym,
      domain: domain,
      region: :global,
    )
    return nil if banner.blank?

    { title: banner.title.presence, body: banner.body }
  end

  def chrome_footer_navigation
    surface = chrome_configuration.fetch(:surface)
    family = chrome_configuration.fetch(:family)
    base_options = { ri: current_region_identifier, host: base_authority_host }

    first_link =
      if chrome_logged_in?
        {
          label: chrome_t("sign.#{surface}.preferences.footer.dashboard"),
          href: chrome_url("base_#{surface}_dashboard_url", base_options),
        }
      else
        { label: chrome_t("sign.#{surface}.preferences.footer.home"),
          href: chrome_url("#{family}_#{surface}_root_path"), }
      end

    [
      first_link,
      {
        label: chrome_t("sign.#{surface}.preferences.footer.preference"),
        href: chrome_url("base_#{surface}_preference_url", base_options),
      },
      {
        label: chrome_t("sign.#{surface}.preferences.footer.settings"),
        href: chrome_url("base_#{surface}_identity_url", base_options),
      },
    ]
  end

  def chrome_cookie_controls
    surface = chrome_configuration.fetch(:surface)
    scope = "layouts.shared.footer_cookie_controls"
    # The cookie screen owns consent while it is being edited; showing the banner there would
    # put two controls for the same decision on one page.
    hidden = params[:action].to_s == "edit" &&
      (params[:preference_screen].to_s == "cookie" || controller_path.end_with?("/preference/cookies"))

    {
      hidden: hidden,
      scope: surface,
      settings_url: chrome_cookie_settings_url(surface),
      title: chrome_t("#{scope}.title"),
      description_html: chrome_t("#{scope}.description_html", privacy_policy: chrome_t("#{scope}.privacy_policy")),
      close_button: chrome_t("#{scope}.close_button"),
      reject_all: chrome_t("#{scope}.reject_all"),
      open_settings: chrome_t("#{scope}.open_settings"),
      accept_all: chrome_t("#{scope}.accept_all"),
    }
  end

  def chrome_cookie_settings_url(surface)
    # Query parameters arrive with string keys; url helpers merge default_url_options under
    # symbols. Passing the strings through as extra options duplicated `ri` on the href, which
    # is how the settings control pointed at a query the destination does not read as one value.
    options = request.query_parameters.slice(*PREFERENCE_QUERY_KEYS).symbolize_keys
    # An auth surface renders on the sign host while cookie preferences are edited on the base
    # authority host, so the link has to be absolute across that boundary.
    options = options.merge(host: base_authority_host) if chrome_configuration.fetch(:footer_navigation)

    chrome_url("edit_base_#{surface}_preference_cookie_url", options)
  end

  # The theme screen owns the theme control while it is being edited; showing the footer copy of it
  # there would put two controls for one value on the same page.
  def chrome_theme_controls
    scope = "layouts.shared.footer_theme_controls"
    hidden = params[:action].to_s == "edit" &&
      (params[:preference_screen].to_s == "theme" || controller_path.end_with?("/preference/themes"))

    {
      hidden: hidden,
      title: chrome_t("#{scope}.title"),
      description: chrome_t("#{scope}.description"),
      options: {
        system: chrome_t("#{scope}.options.system"),
        light: chrome_t("#{scope}.options.light"),
        dark: chrome_t("#{scope}.options.dark"),
      },
    }
  end

  def chrome_copyright
    "© #{Time.zone.today.year} #{ENV.fetch("BRAND_NAME")}"
  end

  def chrome_logged_in?
    respond_to?(:logged_in?, true) && logged_in?
  end

  # Keys are composed from the surface, so they cannot be literals at the call site; passing the
  # composed key through here keeps every translation lookup in one place.
  def chrome_t(key, **)
    t(key, **)
  end

  def chrome_url(helper, options = nil)
    options.present? ? public_send(helper, options) : public_send(helper)
  end
end
