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

    # The receiver declares its policy rather than relying on framework or global defaults.
    protect_from_forgery using: :header_or_legacy_token, with: :exception

    private

    # auth/id is redirect-only here; base/www owns authority mutation.
  end
end
