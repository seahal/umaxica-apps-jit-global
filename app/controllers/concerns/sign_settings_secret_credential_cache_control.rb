# typed: false
# frozen_string_literal: true

# Prevents browser / proxy caching of pages that surface raw secret_credential material
# (e.g. the `new` form shows the freshly-generated raw secret_credential once). Without
# `no-store`, hitting Back or sharing a snapshot can resurrect the plaintext.
module SignSettingsSecretCredentialCacheControl
  extend ActiveSupport::Concern

  private

  def set_no_store_for_secret_credential_pages
    # Rails serializes its `no_store` cache-control flag as only `private, no-store`,
    # dropping the additional directives this secret page contract requires.
    response.cache_control.replace(
      no_cache: true,
      extras: %w(no-store must-revalidate private),
    )
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end
end
