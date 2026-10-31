# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Guard
          class TelephonesController < BaseController
            AUTHENTICATION_MODE = :open
            sign_entry_classification! :sign_up

            private

            def sign_up_family = "telephone"
          end
        end
      end
    end
  end
end
