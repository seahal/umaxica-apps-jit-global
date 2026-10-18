# typed: false
# frozen_string_literal: true

# Sign-out completion for surfaces whose sign-out pages stay in ERB (Core, Edit).
#
# An ERB page cannot carry Inertia's `clearHistory`, but a signed-in session on the same origin may
# have left Inertia history behind: `encrypt_history` only encrypts those entries, and the key that
# decrypts them lives in the tab's sessionStorage. `Clear-Site-Data: "storage"` drops that
# sessionStorage (and localStorage, IndexedDB and service worker registrations) for this origin, so
# the history can no longer be restored without asking the server; `"cache"` drops the HTTP cache
# alongside it. A browser that does not support the header falls back to the existing controls:
# authenticated responses are `no-store` and every re-fetch is authenticated server-side.
#
# Include it only on a surface that registers no service worker it must keep: "storage" also
# unregisters service workers, and Core and Edit register none. Surfaces that render sign-out as an
# Inertia page use `SignOutInertiaPages`, which clears history through `clear_history: true`.
module SignOutClearSiteData
  CLEAR_SITE_DATA = '"cache", "storage"'

  private

  def render_oidc_rp_logout_completion
    response.set_header("Clear-Site-Data", CLEAR_SITE_DATA)
    super
  end
end
