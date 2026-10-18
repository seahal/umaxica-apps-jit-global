# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Sign
      class EntriesController < Core::Com::ApplicationController
        include ::OidcRpSignEntry

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        before_action :reject_authenticated_rp_start!
        helper_method :neutral_sign_form_url
      end
    end
  end
end
