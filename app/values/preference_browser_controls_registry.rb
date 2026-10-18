# typed: false
# frozen_string_literal: true

# Which page families may render the interactive theme and cookie-consent controls, and the
# same-origin endpoint each control talks to.
#
# `app`, `com`, and `org` name a preference domain; they do not say whether a given family's pages
# may offer the controls. Palm shares the `app` surface with Core but has no browser preference
# endpoint, so a surface-only decision rendered controls there that called a route the host does not
# serve. The decision is therefore keyed by family and surface together, and only pairs that exist
# are listed: asking for an unlisted pair (`palm/com`, `core/dev`) raises instead of guessing.
#
# The endpoint path is declared here and handed to the browser through the page chrome, so browser
# code never derives an API path from its own origin. Each path is origin-relative: the request stays
# on the host that holds the host-only preference credentials (adr/cookie-domain-scope-by-surface.md).
# Declaring a path here does not route it; the route contract tests hold each listed family's
# routes to these paths.
#
# See adr/preference-browser-transport-family-capability.md.
module PreferenceBrowserControlsRegistry
  Controls = Data.define(:theme_endpoint_path, :cookie_endpoint_path)

  API_V0 = Controls.new(
    theme_endpoint_path: "/api/v0/preferences/theme",
    cookie_endpoint_path: "/api/v0/preferences/cookie",
  )
  NONE = Controls.new(theme_endpoint_path: nil, cookie_endpoint_path: nil)

  MATRIX = {
    "base" => { "app" => API_V0, "com" => API_V0, "org" => API_V0 }.freeze,
    "auth" => { "app" => API_V0, "com" => API_V0, "org" => API_V0 }.freeze,
    "core" => { "app" => API_V0, "com" => API_V0, "org" => API_V0 }.freeze,
    "warp" => { "app" => API_V0, "com" => API_V0, "org" => API_V0 }.freeze,
    "palm" => { "app" => NONE }.freeze,
    "edit" => { "org" => NONE }.freeze,
  }.freeze

  module_function

  def fetch(family:, surface:)
    surfaces =
      MATRIX.fetch(family.to_s) do
        raise KeyError, "no preference browser controls declared for family #{family.inspect}"
      end

    surfaces.fetch(surface.to_s) do
      raise KeyError, "no preference browser controls declared for #{family}/#{surface.inspect}"
    end
  end
end
