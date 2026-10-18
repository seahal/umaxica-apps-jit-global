# typed: false
# frozen_string_literal: true

module Base
  module Com
    # R5-WU16 Base logout completion: read-only GET and one-shot receipt POST.
    class SignByesController < Base::Com::AuthorityController
      include ::BaseSignBye

      prepend_before_action :apply_default_no_store

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open
    end
  end
end
