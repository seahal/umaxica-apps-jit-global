# typed: false
# frozen_string_literal: true

module Auth
  class RedirectOnlyController < ApplicationController
    include ::SignAcmeAuthorityRedirect
    # Policy root for the Auth redirect-only controllers: the repository-wide ApplicationController
    # it inherits is shared with mounted engines and carries no cache policy of its own.
    include ::DefaultNoStore
    include ::SignEntryClassification

    # D-59: redirect-only endpoints hand the request to the surface that owns the mutation; they are
    # never a Sign Entry, so the family states the exclusion once with its reason.
    sign_entry_classification! :excluded,
                               reason: "authority redirect-only endpoint; the owner surface performs the mutation"

    AUTHENTICATION_MODE = :open

    prepend_before_action :apply_default_no_store

    # The receiver declares its policy rather than relying on framework or global defaults.
    protect_from_forgery using: :header_or_legacy_token, with: :exception

    private

    # auth/id is redirect-only here; base/www owns authority mutation.
  end
end
