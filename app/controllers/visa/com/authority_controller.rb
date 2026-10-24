# typed: false
# frozen_string_literal: true

module Visa
  module Com
    class AuthorityController < ::Base::Com::AuthorityController
      AUTHENTICATION_MODE = :deny_all
    end
  end
end
