# typed: false
# frozen_string_literal: true

module Visa
  module App
    # The initial Visa authority delegates the shared root-session mechanics to
    # the existing authority implementation while exposing a distinct
    # controller namespace and Jump issuer identity. RP concerns are not mixed
    # into this hierarchy.
    class AuthorityController < ::Base::App::AuthorityController
      AUTHENTICATION_MODE = :deny_all
    end
  end
end
