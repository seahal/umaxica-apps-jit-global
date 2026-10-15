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
        prepend_before_action :apply_sign_entry_cache_policy!
        ensure_fqdn_gate_first!
        helper_method :neutral_sign_form_url

        private

        # This entry carries session-bound form state; refusals before the action must also
        # prohibit storage without changing Palm's other public cache contracts.
        def apply_sign_entry_cache_policy!
          response.set_header("Cache-Control", "no-store")
        end
      end
    end
  end
end
