# typed: false
# frozen_string_literal: true

module ApplicationHelper
  # Authentication helpers are provided by AuthenticationClient and AuthenticationOperator concerns
  # No need to define them here - they're already available via helper_method

  EDGE_HOST_ENV_KEYS = {
    app: %w(PUBLIC_EDGE_SERVICE_URL EDGE_SERVICE_URL),
    org: %w(PUBLIC_EDGE_STAFF_URL EDGE_STAFF_URL),
    com: %w(PUBLIC_EDGE_CORPORATE_URL EDGE_CORPORATE_URL),
  }.freeze

  # Brand title editions, matched against the labels of the host actually serving
  # the response. Surface layouts name their TLD literally because the route's
  # `scope(module:)` fixes it; this exists for the two shared views that answer on
  # more than one edition (health, served by Base::App::HealthsController on the
  # .app/.net/.dev hosts, and the PWA offline page, shared across auth and palm).
  BRAND_TLD_LABELS = %w(app com org net dev).freeze

  def brand_tld
    label = request.host.to_s.downcase.split(".").reverse.find { |part| BRAND_TLD_LABELS.include?(part) }

    unless label
      raise ArgumentError, "Cannot derive a brand TLD from host #{request.host.inspect}; " \
                           "expected one of #{BRAND_TLD_LABELS.join(", ")} among its labels"
    end

    label.upcase
  end

  def page_title(title = nil)
    if title.present?
      content_for(:page_title, title)
      title
    else
      # Brand and TLD are a locale-independent contract owned by the layout's
      # meta-tags `site:` value, so there is no translated default here. A page
      # without a title renders the site title alone, which is the root contract.
      content_for(:page_title)
    end
  end

  def theme_cookie_value(value = nil)
    raw = (value || Actor.preferences.theme).to_s.downcase
    {
      "dr" => "dark",
      "dark" => "dark",
      "li" => "light",
      "light" => "light",
      "sy" => "system",
      "system" => "system",
    }[raw] || "system"
  end

  def theme_html_class(value = nil)
    theme = theme_cookie_value(value)
    classes = ["theme-#{theme}"]
    classes << "dark" if theme == "dark"
    classes.join(" ")
  end

  # Backward-compatible name used by some layouts.
  def theme_class
    theme_html_class
  end

  # Delegates to the query object so the layout partial and the Inertia shared props read the
  # banner through one implementation.
  def current_banner_for(tld:, region:, domain:)
    CurrentBannerQuery.call(tld: tld, region: region, domain: domain)
  end

  def edge_host
    surface = request.respond_to?(:host) ? CoreSurface.current(request) : CoreSurface::DEFAULT
    env_key =
      EDGE_HOST_ENV_KEYS.fetch(surface) do
        raise ArgumentError, "no Edge host is configured for surface #{surface.inspect}"
      end

    CoreHostNormalization.normalize(ENV.fetch(env_key.first))
  end
end
