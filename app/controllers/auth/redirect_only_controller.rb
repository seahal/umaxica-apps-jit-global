# typed: false
# frozen_string_literal: true

module Auth
  class RedirectOnlyController < ApplicationController
    include ::SignAcmeAuthorityRedirect
    # Policy root for the Auth redirect-only controllers: the repository-wide ApplicationController
    # it inherits is shared with mounted engines and carries no cache policy of its own.
    include ::DefaultNoStore

    AUTHENTICATION_MODE = :open

    prepend_before_action :apply_default_no_store

    # `using:` must be stated explicitly. Omitting it falls back to
    # config.load_defaults(8.2), which sets forgery_protection_verification_strategy
    # to :header_only - stricter than every other surface here, and it rejects
    # browsers that do not send Sec-Fetch-Site, which is exactly the case
    # :header_or_legacy_token exists to cover.
    protect_from_forgery using: :header_or_legacy_token, with: :exception

    private

    # auth/id is redirect-only here; base/www owns authority mutation.
  end
end
