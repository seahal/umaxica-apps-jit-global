# typed: false
# frozen_string_literal: true

module Base
  module App
    module Sign
      class EntriesController < Base::App::ApplicationController
        include ::BaseNeutralSignEntry

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        helper_method :neutral_sign_form_url

        private

        # The start POST only issues an admission; it needs no preference authority, so a stale
        # preference credential must not refuse it.
        def preference_entry_recovery_action?
          action_name == "create"
        end

        def base_sign_surface = "app"

        def auth_sign_in_url_for(admission)
          auth_app_sign_in_url(
            ri: params[:ri], host: oidc_sign_host, protocol: "https", entry_ref: admission.reference,
          )
        end
      end
    end
  end
end
