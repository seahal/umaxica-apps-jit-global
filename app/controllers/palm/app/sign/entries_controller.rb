# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Sign
      # Palm uses the shared passive GET and CSRF-protected POST Browser RP entry. The flow's
      # client, redirect URI, PKCE verifier, state and nonce are all selected and held server-side.
      class EntriesController < Palm::App::ApplicationController
        include ::OidcRpSignEntry

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        before_action :reject_authenticated_rp_start!
        helper_method :neutral_sign_form_url

        private
      end
    end
  end
end
